defmodule Shortener.AggregatesTest do
  use ExUnit.Case, async: false

  import Shortener.TestUtils

  alias Shortener.{
    Aggregates,
    Cluster,
    LinkManager.Cache,
    Storage,
  }

  setup_all do
    System.put_env("PORT", "4000")
    System.put_env("SHORTENER1_PORT", "4001")
    System.put_env("SHORTENER2_PORT", "4002")
    System.put_env("SHORTENER3_PORT", "4003")

    Application.ensure_all_started(:shortener)
    nodes = LocalCluster.start_nodes("shortener", 3)
    Cluster.set_canonical_nodes([Node.self() | nodes])
    Cluster.update_ring()

    for node <- nodes do
      :rpc.call(node, Shortener.Cluster, :update_ring, [])
    end

    {:ok, nodes: nodes}
  end

  setup do
    Storage.flush()
    GenServer.multi_call(Cache, :flush)
    GenServer.multi_call(Aggregates, :flush)

    :ok
  end

  test "aggregates can be shared across nodes", %{nodes: nodes} do
    [n1, n2, n3] = nodes
    Aggregates.increment("outlaws")

    eventually(fn ->
      assert Aggregates.count_for("outlaws") == 1
      assert :rpc.call(n1, Aggregates, :count_for, ["outlaws"]) == 1
      assert :rpc.call(n2, Aggregates, :count_for, ["outlaws"]) == 1
      assert :rpc.call(n3, Aggregates, :count_for, ["outlaws"]) == 1
    end)
  end

  test "aggregates recover from netsplits", %{nodes: nodes} do
    [n1, n2, n3] = nodes

    Schism.partition([n1, n2])

    # These will be unseen by 1 and 2
    Aggregates.increment({Aggregates, n3}, "outlaws")
    Aggregates.increment({Aggregates, n3}, "outlaws")
    Aggregates.increment({Aggregates, n3}, "outlaws")

    # These will be unseen by 3
    Aggregates.increment({Aggregates, n1}, "outlaws")
    Aggregates.increment({Aggregates, n1}, "outlaws")
    Aggregates.increment({Aggregates, n2}, "outlaws")

    eventually(fn ->
      assert :rpc.call(n1, Aggregates, :count_for, ["outlaws"]) == 3
      assert :rpc.call(n2, Aggregates, :count_for, ["outlaws"]) == 3
      assert :rpc.call(n3, Aggregates, :count_for, ["outlaws"]) == 3
    end)

    Schism.heal([n1, n2, n3])

    # Healing should trigger each node to merge their respective counters
    eventually(fn ->
      assert :rpc.call(n1, Aggregates, :count_for, ["outlaws"]) == 6
      assert :rpc.call(n2, Aggregates, :count_for, ["outlaws"]) == 6
      assert :rpc.call(n3, Aggregates, :count_for, ["outlaws"]) == 6
    end)
  end

  test "aggregates are shared across nodes", %{nodes: nodes} do
    [n1, n2, n3] = nodes
    resp = post("http://localhost:4001", %{"url" => "https://keathley.io"})
    assert resp.status_code == 201
    assert {_, short_link} = Enum.find(resp.headers, fn {h, _} -> h == "location" end)

    resp = get(short_link)
    assert resp.status_code == 302

    hash = URI.parse(short_link).path

    # Check all nodes for values
    eventually(fn ->
      resp = get("http://localhost:4001" <> hash <> "/aggregates")
      assert resp.body == "Redirects: 1"
    end)

    eventually(fn ->
      resp = get("http://localhost:4002" <> hash <> "/aggregates")
      assert resp.body == "Redirects: 1"
    end)

    eventually(fn ->
      resp = get("http://localhost:4003" <> hash <> "/aggregates")
      assert resp.body == "Redirects: 1"
    end)

    Schism.partition([n1, n2])

    resp = get("http://localhost:4001" <> hash)
    assert resp.status_code == 302

    # Only n1 and n2 should be updated. n3 should have the old values

    eventually(fn ->
      resp = get("http://localhost:4001" <> hash <> "/aggregates")
      assert resp.body == "Redirects: 2"
    end)

    eventually(fn ->
      resp = get("http://localhost:4002" <> hash <> "/aggregates")
      assert resp.body == "Redirects: 2"
    end)

    eventually(fn ->
      resp = get("http://localhost:4003" <> hash <> "/aggregates")
      assert resp.body == "Redirects: 1"
    end)

    resp = get("http://localhost:4002" <> hash)
    assert resp.status_code == 302

    resp = get("http://localhost:4001" <> hash)
    assert resp.status_code == 302

    resp = get("http://localhost:4003" <> hash)
    assert resp.status_code == 302

    eventually(fn ->
      resp = get("http://localhost:4001" <> hash <> "/aggregates")
      assert resp.body == "Redirects: 4"
    end)

    eventually(fn ->
      resp = get("http://localhost:4002" <> hash <> "/aggregates")
      assert resp.body == "Redirects: 4"
    end)

    eventually(fn ->
      resp = get("http://localhost:4003" <> hash <> "/aggregates")
      assert resp.body == "Redirects: 2"
    end)

    Schism.heal([n1, n2, n3])

    eventually(fn ->
      resp = get("http://localhost:4001" <> hash <> "/aggregates")
      assert resp.body == "Redirects: 5"
    end)

    eventually(fn ->
      resp = get("http://localhost:4002" <> hash <> "/aggregates")
      assert resp.body == "Redirects: 5"
    end)

    eventually(fn ->
      resp = get("http://localhost:4003" <> hash <> "/aggregates")
      assert resp.body == "Redirects: 5"
    end)
  end
end

