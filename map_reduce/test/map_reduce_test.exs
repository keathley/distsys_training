defmodule MapReduceTest do
  use ExUnit.Case, async: false

  alias MapReduce.Workers

  setup_all do
    Application.ensure_all_started(:map_reduce)

    :ok
  end

  # setup do
  #   nodes = LocalCluster.start_nodes("mr-cluster", 2)

  #   {:ok, nodes: nodes}
  # end

  describe "WordCount" do
    alias MapReduce.WordCount

    test "can count word occurences" do
      assert WordCount.process("foo bar foo baz") == %{
        "foo" => 2,
        "bar" => 1,
        "baz" => 1,
      }

      foo = Stream.repeatedly(fn -> "foo" end) |> Enum.take(10)
      bar = Stream.repeatedly(fn -> "bar" end) |> Enum.take(20)
      baz = Stream.repeatedly(fn -> "baz" end) |> Enum.take(30)

      content =
        (foo ++ bar ++ baz)
        |> Enum.shuffle
        |> Enum.join(" ")

      assert WordCount.process(content) == %{
        "foo" => 10,
        "bar" => 20,
        "baz" => 30
      }
    end
  end

  test "can start workers" do
    assert {:ok, pid} = MapReduce.Workers.start_worker(Node.self(), self())
  end

  test "can start workers on remote nodes" do
    [n1] = LocalCluster.start_nodes("mr-cluster", 1)

    assert {:ok, pid} = MapReduce.Workers.start_worker(n1, self())
  end

  test "after the worker is started it lets the manager know its ready for work" do
    assert {:ok, worker_pid} = MapReduce.Workers.start_worker(self())
    assert_receive {_cast, {:worker_is_ready, ^worker_pid}}
  end

  test "the manager should keep track of the workers" do
    assert {:ok, worker_pid} = MapReduce.Workers.start_worker(MapReduce.Manager)

    eventually(fn ->
      assert MapReduce.Manager.workers() == [worker_pid]
    end)
  end

  test "workers can execute work and cast their results back to the manager" do
    assert {:ok, worker} = MapReduce.Workers.start_worker(self())
    assert_receive {_, {:worker_is_ready, ^worker}}

    MapReduce.Workers.run_job(worker, {0, "foo bar baz"}, MapReduce.WordCount)

    assert_receive {_cast, {:finished, {0, results}, ^worker}}
    assert results == %{"foo" => 1, "bar" => 1, "baz" => 1}
  end

  def eventually(f, retries \\ 0) do
    f.()
  rescue
    err ->
    if retries >= 10 do
      reraise err, __STACKTRACE__
    else
      :timer.sleep(500)
      eventually(f, retries + 1)
    end
  catch
    _exit, _term ->
    :timer.sleep(500)
    eventually(f, retries + 1)
  end
end
