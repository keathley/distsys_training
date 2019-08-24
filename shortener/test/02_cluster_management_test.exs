defmodule Shortener.ClusterManagementTest do
  use ExUnit.Case, async: false

  import Shortener.TestUtils

  alias Shortener.Cluster
  alias Shortener.Storage
  alias Shortener.LinkManager
  alias Shortener.LinkManager.Cache

  setup_all do
    System.put_env("PORT", "4000")
    System.put_env("SHORTENER1_PORT", "4001")
    System.put_env("SHORTENER2_PORT", "4002")
    System.put_env("SHORTENER3_PORT", "4003")

    Application.ensure_all_started(:shortener)

    nodes = LocalCluster.start_nodes("shortener", 3)
    Cluster.set_canonical_nodes(nodes)
    Cluster.update_ring()

    for node <- nodes do
      :rpc.call(node, Shortener.Cluster, :update_ring, [])
    end

    {:ok, nodes: nodes}
  end

  setup do
    Storage.flush()
    GenServer.multi_call(Cache, :flush)

    :ok
  end

  test "cluster membership can be set", %{nodes: nodes} do
    [n1, n2, n3] = nodes
    Cluster.set_canonical_nodes(nodes)
    assert :ok = Cluster.update_ring()
    assert n3 == Cluster.find_node("a")
    assert n1 == Cluster.find_node("b")
    assert n2 == Cluster.find_node("c")
  end

  test "links are routed to specific boxes", %{nodes: nodes} do
    [_n1, _n2, n3] = nodes
    url = "https://elixiroutlaws.com"

    assert {:ok, code} = LinkManager.create(url)

    # We should not have loaded our local cache since we're creating a
    # record on a remote node.
    assert {:error, :not_found} == Cache.lookup(code)
    assert {:ok, url} == :rpc.call(n3, Cache, :lookup, [code])
  end

  test "doing a remote lookup on another node loads the link into memory", %{nodes: nodes} do
    [_n1, _n2, n3] = nodes
    url = "https://elixiroutlaws.com"

    # Creating this code will load it into the ets cache. We flush the cache
    # to ensure nothing is in there before we do the remote lookup.
    assert {:ok, code} = LinkManager.create(url)
    :ok = Cache.flush({Cache, n3})
    assert {:error, :not_found} == :rpc.call(n3, Cache, :lookup, [code])

    # Running the remote_lookup should re-load the record into that nodes ets
    # cache.
    assert {:ok, url} == LinkManager.remote_lookup(code)
    assert {:ok, url} == :rpc.call(n3, Cache, :lookup, [code])
  end

  test "during partitions creation and remote lookups are unavailable", %{nodes: nodes} do
    [n1, n2, n3] = nodes
    url = "https://elixiroutlaws.com"

    # This specific url hashes into node 3 so we separate it from the cluster.
    Schism.partition([n3])
    assert {:error, :node_down} == :rpc.call(n1, LinkManager, :create, [url])

    # Since we're the manager we can still reach n3.
    assert {:ok, code} = LinkManager.create(url)

    # Node 2 should not be able to lookup urls on n3.
    assert {:error, :node_down} == :rpc.call(n2, LinkManager, :remote_lookup, [code])

    # Heal the partition
    Schism.heal([n3])

    assert {:ok, ^url} = :rpc.call(n1, LinkManager, :remote_lookup, [code])
    assert {:ok, ^url} = :rpc.call(n2, LinkManager, :remote_lookup, [code])
  end

  test "api utilizes remote creation", %{nodes: nodes} do
    [n1, n2, n3] = nodes
    url = "https://elixiroutlaws.com"

    resp = post("http://localhost:4000", %{"url" => url})
    assert resp.status_code == 201
    short_code = resp.body

    assert {:error, :not_found} == :rpc.call(n1, Cache, :lookup, [short_code])
    assert {:error, :not_found} == :rpc.call(n2, Cache, :lookup, [short_code])
    assert {:ok, url} == :rpc.call(n3, Cache, :lookup, [short_code])
  end

  test "api uses remote lookups", %{nodes: nodes} do
    [n1, n2, n3] = nodes
    url = "https://elixiroutlaws.com"

    resp = post("http://localhost:4000", %{"url" => url})
    assert resp.status_code == 201
    short_code = resp.body

    for i <- 1..3 do
      resp = get("http://localhost:400#{i}/#{short_code}")
      assert resp.status_code == 302
      assert {_, ^url} = Enum.find(resp.headers, fn {h, _} -> h == "location" end)
      assert url == resp.body
    end

    assert {:error, :not_found} = :rpc.call(n1, Cache, :lookup, [short_code])
    assert {:error, :not_found} = :rpc.call(n2, Cache, :lookup, [short_code])
    assert {:ok, url} == :rpc.call(n3, Cache, :lookup, [short_code])
  end

  test "api if remote lookup we fetch from storage", %{nodes: nodes} do
    [n1, n2, n3] = nodes
    url = "https://elixiroutlaws.com"

    resp = post("http://localhost:4000", %{"url" => url})
    assert resp.status_code == 201
    short_code = resp.body

    # nodes 1 and 2 will not be able to talk to node 3
    Schism.partition([n1, n2])

    for i <- 1..2 do
      resp = get("http://localhost:400#{i}/#{short_code}")
      assert resp.status_code == 302
      assert {_, ^url} = Enum.find(resp.headers, fn {h, _} -> h == "location" end)
      assert url == resp.body
    end
  end
end

