defmodule ChannelLockTest do
    use ExUnit.Case, async: false
    doctest ChannelLock

    test "Basic blocking task" do
        ret = ChannelLock.request(1, fn -> 
            :timer.sleep(100)
            "return"
        end)
        assert ret == "return"
    end

    test "Different timed multiple tasks" do
        a = Task.async(fn -> 
            ChannelLock.request(2, fn -> 
                :timer.sleep(1000)
                1 |> IO.inspect
            end)
        end)
        b = Task.async(fn -> 
            ChannelLock.request(2, fn -> 
                :timer.sleep(100)
                2 |> IO.inspect
            end)
        end)
        c = Task.async(fn -> 
            ChannelLock.request(2, fn -> 
                :timer.sleep(500)
                3 |> IO.inspect
            end)
        end)
        t = [
            a, b, c
        ] |> Enum.map(fn func -> Task.await(func) end)
        assert t == [1, 2, 3]
    end

    test "Same time multiple tasks" do
        func = fn ret -> 
            :timer.sleep(100)
            ret |> IO.inspect
        end
        a = Task.async(fn -> 
            ChannelLock.request(2, fn -> func.(1) end)
        end)
        b = Task.async(fn -> 
            ChannelLock.request(2, fn -> func.(2) end)
        end)
        c = Task.async(fn -> 
            ChannelLock.request(2, fn -> func.(3) end)
        end)
        t = [
            a, b, c
        ] |> Enum.map(fn func -> Task.await(func) end)
        assert t == [1, 2, 3]
    end
end
