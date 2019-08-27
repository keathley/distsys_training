defmodule ShortenerTest do
  use ExUnit.Case, async: false

  import Shortener.TestUtils

  alias Shortener.{
    Cluster,
    LinkManager,
    LinkManager.Cache,
    Storage,
  }

  setup_all do
    System.put_env("PORT", "4000")
    System.put_env("SHORTENER1_PORT", "4001")
    System.put_env("SHORTENER2_PORT", "4002")
    System.put_env("SHORTENER3_PORT", "4003")

    Application.ensure_all_started(:shortener)
    # Ignore these lines for now ;). They're only here so we don't break
    # these tests in the next section
    nodes = LocalCluster.start_nodes("shortener", 2)
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

    :ok
  end

  describe "Cache" do
    test "can store urls" do
      assert Cache.lookup("shortcode") == {:error, :not_found}
      Cache.insert("shortcode", "https://elixiroutlaws.com")
      assert Cache.lookup("shortcode") == {:ok, "https://elixiroutlaws.com"}
    end

    test "after a cache miss the cache is updated" do
      url = "https://elixiroutlaws.com"
      assert {:ok, code} = LinkManager.create(url)
      assert :ok == Cache.flush()
      assert {:error, :not_found} == Cache.lookup(code)
      assert {:ok, url} == LinkManager.lookup(code)
      assert {:ok, url} == Cache.lookup(code)
    end
  end

  describe "clustered" do
    test "it shortens links" do
      resp = post("http://localhost:4000", %{"url" => "https://keathley.io"})
      assert resp.status_code == 201
      assert {_, short_link} = Enum.find(resp.headers, fn {h, _} -> h == "location" end)

      resp = get(short_link)
      assert resp.status_code == 302
      assert {_, "https://keathley.io"} = Enum.find(resp.headers, fn {h, _} -> h == "location" end)
      assert "https://keathley.io" = resp.body
    end

    test "all nodes can see a new short link", %{nodes: nodes} do
      url = "https://elixiroutlaws.com"
      [n1, n2] = nodes

      assert {:ok, code} = LinkManager.create(url)
      assert {:ok, ^url} = LinkManager.lookup(code)

      eventually(fn ->
        assert {:ok, ^url} = :rpc.call(n1, LinkManager, :lookup, [code])
        assert {:ok, ^url} = :rpc.call(n2, LinkManager, :lookup, [code])
      end)
    end

    test "links can be returned even during a partition", %{nodes: nodes} do
      url = "https://elixiroutlaws.com"
      [n1, n2] = nodes

      Schism.partition([n1])

      assert{:ok, code} = :rpc.call(n2, LinkManager, :create, [url])

      eventually(fn ->
        assert {:ok, ^url} = LinkManager.lookup(code)
        assert {:ok, ^url} = :rpc.call(n1, LinkManager, :lookup, [code])
      end)
    end
  end
end

