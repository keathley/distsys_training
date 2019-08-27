defmodule Shortener.Router do
  use Plug.Router

  require Logger

  alias Plug.Conn
  alias Shortener.{
    Aggregates,
    LinkManager,
    Storage,
  }

  plug Plug.Logger, log: :debug
  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart],
    pass: ["text/*"]
  plug :match
  plug :dispatch

  post "/" do
    %{"url" => url} = conn.params

    case LinkManager.create(url) do
      {:ok, short_code} ->
        conn
        |> put_resp_header("location", short_link(conn, short_code))
        |> send_resp(201, short_code)

      {:error, _} ->
        conn
        |> send_resp(422, "Unable to shorten #{url}")
    end
  end

  get "/:hash" do
    case LinkManager.lookup(hash) do
      {:ok, url} ->
        conn
        |> put_resp_header("location", url)
        |> send_resp(302, url)

      {:error, _} ->
        send_resp(conn, 404, "Not Found")
    end
  end

  get "/:hash/aggregates" do
    count = Aggregates.count_for(hash)

    conn
    |> send_resp(200, "Redirects: #{count}")
  end

  match _ do
    send_resp(conn, 404, "oops")
  end

  defp short_link(conn, code) do
    conn
    |> Conn.request_url
    |> URI.merge(code)
    |> to_string
  end
end
