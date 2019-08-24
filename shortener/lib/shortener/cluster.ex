defmodule Shortener.Cluster do
  @moduledoc """
  This module provides an interface for updating clusters as well as a
  supervision tree for starting and stopping node discovery.
  """

  alias Shortener.Storage

  alias ExHashRing.HashRing

  @ring_key {__MODULE__, :hash_ring}

  def child_spec(_args) do
    children = [
      {Cluster.Supervisor, [topology(), [name: Shortener.ClusterSupervisor]]},
    ]

    %{
      id: __MODULE__,
      type: :supervisor,
      start: {Supervisor, :start_link, [children, [strategy: :one_for_one]]}
    }
  end

  def find_node(key) do
    # TODO - Update with hash ring lookup
    ring = :persistent_term.get(@ring_key)
    HashRing.find_node(ring, key)
  end

  # Sets the canonical set of nodes into persistent storage.
  def set_canonical_nodes(nodes) do
    bin = :erlang.term_to_binary(nodes)
    :ok = Storage.set("shortener:cluster", bin)
  end

  def update_ring do
    # TODO - Fetch nodes from persistent store, update hash ring
    # put the hash ring into persistent term storage.
    {:ok, bin} = Storage.get("shortener:cluster")
    nodes = :erlang.binary_to_term(bin)
    ring = Enum.reduce(nodes, HashRing.new(), fn node, ring ->
      {:ok, ring} = HashRing.add_node(ring, node)
      ring
    end)

    :persistent_term.put(@ring_key, ring)
    :ok
  end

  defp topology do
    [
      shortener: [
        strategy: Cluster.Strategy.Gossip,
      ]
    ]
  end
end
