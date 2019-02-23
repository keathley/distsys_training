defmodule MapReduceDistTest do
  use ExUnit.Case

  test "handles network partitions and errors" do
    nodes = LocalCluster.start_nodes("mr-cluster", 3)
    [n1, n2, n3] = nodes

    us = self()

    spawn(fn ->
      result = start_job(n1)
      send(us, {:finished, result})
    end)

    Schism.partition([n1, n2])
    Schism.partition([n3])
    Schism.heal([n1, n2, n3])
    Schism.partition([n1])
    Schism.heal([n1, n2, n3])
    LocalCluster.stop_nodes([n2])

    assert_receive {:finished, result}, 20_000

    assert result
    |> Enum.sort_by(fn {_, v} -> v end, &>=/2)
    |> Enum.take(10) == [
      {"the", 62075},
      {"and", 38850},
      {"of", 34434},
      {"to", 13384},
      {"And", 12846},
      {"that", 12577},
      {"in", 12334},
      {"shall", 9760},
      {"he", 9666},
      {"unto", 8940}
    ]
  end

  def start_job(node) do
    :rpc.call(node, MapReduce, :start_dist_job, ["test", "priv/input.txt"])
  end
end

