defmodule Margarine.AggregateTests do
  use ExUnit.Case

  alias Margarine.Storage

  setup_all do
    System.put_env("PORT", "4000")
    System.put_env("MARGARINE1_PORT", "4001")
    System.put_env("MARGARINE2_PORT", "4002")
    System.put_env("MARGARINE3_PORT", "4003")
    Application.ensure_all_started(:margarine)

    :ok
  end

  setup do
    Storage.flush()

    :ok
  end

  test "aggregates are shared across nodes" do
    [n1, n2, n3] = LocalCluster.start_nodes("margarine", 3)

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
      assert resp.body == "Redirects: 1"
    end)

    Schism.heal([n1, n2, n3])

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
      assert resp.body == "Redirects: 4"
    end)
  end

  def eventually(f, retries \\ 0) do
    f.()
  rescue
    err ->
      if retries >= 10 do
        raise err
      else
        :timer.sleep(200)
        eventually(f, retries + 1)
      end
  end

  def post(url, params) do
    headers = [
      {"Content-Type", "application/x-www-form-urlencoded"}
    ]
    HTTPoison.post!(url, URI.encode_query(params), headers)
  end

  def get(url) do
    HTTPoison.get!(url)
  end
end

