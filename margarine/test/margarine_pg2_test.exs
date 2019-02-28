defmodule Margarine.Pg2Test do
  use ExUnit.Case

  alias Margarine.Cache

  setup_all do
    System.put_env("PORT", "4000")
    System.put_env("MARGARINE1_PORT", "4001")
    System.put_env("MARGARINE2_PORT", "4002")
    System.put_env("MARGARINE3_PORT", "4003")
    Application.ensure_all_started(:margarine)

    :ok
  end

  setup do
    Cache.flush()

    :ok
  end

  test "links are shared across nodes" do
    LocalCluster.start_nodes("margarine", 3)

    resp = post("http://localhost:4001", %{"url" => "https://bgmarx.com"})
    assert resp.status_code == 201
    assert {_, short_link} = Enum.find(resp.headers, fn {h, _} -> h == "location" end)
    IO.inspect(short_link, label: "fist")
    resp = get(short_link)
    assert resp.status_code == 302

    hash = URI.parse(short_link).path

    # Check all nodes for values
    eventually(fn ->
      resp = get("http://localhost:4001" <> hash)
      assert resp.body == "https://bgmarx.com"
    end)

    eventually(fn ->
      resp = get("http://localhost:4002" <> hash)
      assert resp.body == "https://bgmarx.com"
    end)

    eventually(fn ->
      resp = get("http://localhost:4003" <> hash)
      assert resp.body == "https://bgmarx.com"
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
