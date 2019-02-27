defmodule Margarine.Router do
  use Plug.Router

  require Logger

  alias Plug.Conn
  alias Margarine.Linker

  plug Plug.Logger, log: :debug
  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart],
    pass: ["text/*"]
  plug :match
  plug :dispatch

  post "/" do
    %{"url" => url} = conn.params
    code = conn.params["code"]
    case Linker.create(url, code) do
      {:ok, code} ->
        conn
        |> put_resp_header("location", short_link(conn, code))
        |> send_resp(201, code)

      {:error, :taken} ->
        conn
        |> send_resp(422, "Unable to shorten #{url}")
    end
  end

  get "/:hash" do
    case Linker.lookup(hash) do
      {:ok, url} ->
        conn
        |> put_resp_header("location", url)
        |> send_resp(302, url)

      {:error, :not_found} ->
        send_resp(conn, 404, "Not Found")
    end
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
