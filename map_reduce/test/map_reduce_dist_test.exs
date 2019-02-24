defmodule MapReduceDistTest do
  use ExUnit.Case

  alias MapReduce.{
    Identity,
    Worker,
    Storage,
  }

  require Logger

  def check(file, result) do
    input_lines =
      file
      |> File.stream!(trim: true)
      |> Stream.map(&String.trim/1)
      |> Enum.to_list
      |> Enum.map(&String.to_integer/1)
      |> Enum.sort

    output_lines =
      result
      |> Enum.map(fn {k, _} -> k end)
      |> Enum.map(&String.to_integer/1)
      |> Enum.sort

    assert input_lines == output_lines
  end

  def check_workers(workers) do
    for worker <- workers do
      {:ok, count} = Storage.get(:erlang.term_to_binary(worker))
      assert count > 0, "Worker: #{inspect worker} never did any work"
    end
  end

  setup_all do
    LocalCluster.start()
    Application.ensure_all_started(:map_reduce)

    :ok
  end

  setup do
    Storage.flush()

    vals =
      Stream.iterate(0, & &1+1)
      |> Stream.map(&Integer.to_string/1)
      |> Enum.take(100_000)
      |> Enum.join("\n")

    File.write!("mr-test-input.txt", vals)

    on_exit fn ->
      File.rm("mr-test-input.txt")
    end

    :ok
  end

  test "handles worker failures" do
    us = self()
    master = spawn(fn ->
      MapReduce.master(us, Identity, "worker-test", "mr-test-input.txt")
    end)

    w1 = spawn(fn -> Worker.start(master, 3) end)
    w2 = spawn(fn -> Worker.start(master, -1) end)

    assert_receive {:result, result}, 3_000
    check("mr-test-input.txt", result)
    check_workers([w1, w2])
  end

  test "handles large scale worker failure" do
    us = self()
    master = spawn(fn ->
      MapReduce.master(us, Identity, "worker-test", "mr-test-input.txt")
    end)
    spawn_failing_workers(master)
  end

  @tag :focus
  test "handles network failures" do
    [n1, n2, n3] = LocalCluster.start_nodes("mr", 3)
    :pong = Node.ping(n1)
    :pong = Node.ping(n2)
    :pong = Node.ping(n3)

    us = self()

    master = Node.spawn(n1,
      MapReduce, :master, [us, Identity, "worker-test", "mr-test-input.txt"])

    Node.spawn(n2, Worker, :start, [master])
    Node.spawn(n3, Worker, :start, [master])
    Node.spawn(n3, Worker, :start, [master])

    :timer.sleep(100)
    Schism.partition([n1, n2])
    :timer.sleep(100)
    Schism.heal([n1, n2])
    :timer.sleep(100)
    Schism.partition([n1, n3])
    :timer.sleep(100)
    Schism.heal([n1, n2, n3])
    :timer.sleep(100)
    Schism.partition([n1])
    :timer.sleep(100)
    Schism.heal([n1, n2, n3])

    assert_receive {:result, result}, 5_000
    check("mr-test-input.txt", result)
  end

  def spawn_failing_workers(master) do
    receive do
      {:result, result} ->
        check("mr-test-input.txt", result)
    after 500 ->
      spawn(fn -> Worker.start(master, 3) end)
      spawn(fn -> Worker.start(master, 3) end)
      spawn_failing_workers(master)
    end
  end
end

