defmodule ChannelLock do
    @moduledoc """
    ChannelLock main API
    """

    @doc false
    def start(_type, _args) do
        import Supervisor.Spec, warn: false
        Supervisor.start_link(
            [worker(ChannelLock.Server, [])],
            strategy: :one_for_one
        )
    end

    @doc """
    Make channel to lock and queue
    """
    def request(channel, func) when is_function(func) do
        GenServer.cast(
            ChannelLock.Server,
            {:channel_call, {channel, self(), func}}
        )
        receive do
            ret -> ret
        end
    end

    @doc """
    Clear lock channel
    """
    def clear(channel) do
        GenServer.cast(
            ChannelLock.Server,
            {:channel_clear, channel}
        )
    end

    @doc """
    Clear locks map
    """
    def clear_all do
        GenServer.cast(
            ChannelLock.Server,
            {:clear}
        )
    end
end

defmodule ChannelLock.Server do
    @moduledoc false

    use GenServer

    def start_link do
        GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
    end

    def init(:ok) do
        {:ok, %{}}
    end

    # Recursive queue based on channel key:
    # Calling the critical code, then moving to the next in queue
    defp run(channel, server_proc) do
        Task.start_link(fn -> 
            %{
                ^channel => %{active: {call_proc, func}}
            } = :sys.get_state(server_proc)
            resp = func.()
            send call_proc, resp
            next_task = GenServer.call(__MODULE__, {:pop_task, channel})
            if next_task == true do
                run(channel, server_proc)
            end
        end)
    end

    # Look for next task in queue, if exists make it the active task
    # Else, delete the channel structure when reaching end of queue
    def handle_call({:pop_task, channel}, _from, locks) do
        %{^channel => cond_struct} = locks
        %{queue: queue} = cond_struct
        if length(queue) > 0 do
            {val, new_queue} = List.pop_at(queue, 0)
            new_locks = %{
                locks |
                channel => %{
                    active: val,
                    queue: new_queue
                }
            }
            {:reply, true, new_locks}
        else
            {:reply, false, Map.delete(locks, channel)}
        end
    end

    # If channel not found, load new channel structure and run the queue
    # Else, load in the queue for execution
    def handle_cast({:channel_call, {channel, process, func}}, locks) do
        with %{^channel => procs} <- locks,
            %{queue: queue} <- procs
        do
            new_locks = %{
                locks |
                channel => %{
                    procs | 
                    queue: queue ++ [{process, func}]
                }
            }
            {:noreply, new_locks}
        else
            _ ->
                new_locks = Map.put(locks, channel, %{
                    active: {process, func}, 
                    queue: []
                })
                run(channel, self())
                {:noreply, new_locks} 
        end
    end

    # Clear channel in locks map
    def handle_cast({:channel_clear, channel}, locks) do
        {:noreply, Map.delete(locks, channel)}
    end

    # Clear all locks map
    def handle_cast({:clear}, _locks) do
        {:noreply, %{}}
    end
end