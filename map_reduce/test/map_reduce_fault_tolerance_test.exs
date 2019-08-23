defmodule MapReduceFaultToleranceTest do
  use ExUnit.Case, async: false

  setup_all do
    Application.ensure_all_started(:map_reduce)

    :ok
  end

  setup do
    vals =
      Stream.iterate(0, & &1+1)
      |> Stream.map(&Integer.to_string/1)
      |> Enum.take(100_000)
      |> Enum.join("\n")

    File.write!("mr-test-input.txt", vals)

    on_exit fn ->
      File.rm("mr-test-input.txt")
    end

    nodes = LocalCluster.start_nodes("mr-faults", 2)

    {:ok, nodes: nodes}
  end

  test "managers can run jobs" do
    MapReduce.Manager.start_job(%{num_workers: 16, input: "mr-test-input.txt"})
    assert_receive {:results, results}, 5_000

    check("mr-test-input.txt", results)
  end

  def check(file, result) do
    input_lines =
      file
      |> File.stream!()
      |> Stream.map(&String.trim/1)
      |> Enum.to_list
      |> IO.inspect(label: "Did we get here")
      |> Enum.map(&String.to_integer/1)
      |> Enum.sort
      |> IO.inspect(label: "How about here?")

    output_lines =
      result
      |> Enum.map(fn {k, _} -> k end)
      |> Enum.map(&String.to_integer/1)
      |> Enum.sort

    assert input_lines == output_lines
  end
end

