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

    resp = get(short_link <> "/aggregates")
    assert resp.status_code == 200
    assert resp.body == "Redirects: 1"

    # resp = get(short_link <> "/aggregates")
    # assert resp.status_code == 200
    # assert resp.body == "Redirects: 1"
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

