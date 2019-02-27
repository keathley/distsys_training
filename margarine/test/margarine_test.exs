defmodule MargarineTest do
  use ExUnit.Case

  alias Margarine.Storage

  setup_all do
    System.put_env("PORT", "4001")
    Application.ensure_all_started(:margarine)

    :ok
  end

  setup do
    Storage.flush()

    :ok
  end

  test "it shortens links" do
    resp = post("http://localhost:4001", %{"url" => "https://keathley.io"})
    assert resp.status_code == 201
    assert {_, short_link} = Enum.find(resp.headers, fn {h, _} -> h == "location" end)

    resp = get(short_link)
    assert resp.status_code == 302
    assert {_, "https://keathley.io"} = Enum.find(resp.headers, fn {h, _} -> h == "location" end)
    assert "https://keathley.io" = resp.body
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
