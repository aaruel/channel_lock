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
    Make condition to lock and queue, block acting as a function
    """
    def push(condition, block) when is_function(block) do
        GenServer.cast(
            ChannelLock.Server,
            {:channel_call, {condition, self(), block}}
        )
        receive do
            ret -> ret
        end
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

    # Recursive queue based on condition key:
    # Calling the critical code, then moving to the next in queue
    defp run(condition, server_proc) do
        Task.start_link(fn -> 
            %{
                ^condition => %{active: {call_proc, func}}
            } = :sys.get_state(server_proc)
            resp = func.()
            send call_proc, resp
            next_task = GenServer.call(__MODULE__, {:pop_task, condition})
            if next_task == true do
                run(condition, server_proc)
            end
        end)
    end

    # Look for next task in queue, if exists make it the active task
    # Else, delete the condition structure when reaching end of queue
    def handle_call({:pop_task, condition}, _from, locks) do
        %{^condition => cond_struct} = locks
        %{queue: queue} = cond_struct
        if length(queue) > 0 do
            {val, new_queue} = List.pop_at(queue, 0)
            new_locks = %{
                locks |
                condition => %{
                    active: val,
                    queue: new_queue
                }
            }
            {:reply, true, new_locks}
        else
            {:reply, false, Map.delete(locks, condition)}
        end
    end

    # If condition not found, load new condition structure and run the queue
    # Else, load in the queue for execution
    def handle_cast({:channel_call, {condition, process, func}}, locks) do
        with %{^condition => procs} <- locks,
            %{queue: queue} <- procs
        do
            new_locks = %{
                locks |
                condition => %{
                    procs | 
                    queue: queue ++ [{process, func}]
                }
            }
            {:noreply, new_locks}
        else
            _ ->
                new_locks = Map.put(locks, condition, %{
                    active: {process, func}, 
                    queue: []
                })
                run(condition, self())
                {:noreply, new_locks} 
        end
    end
end