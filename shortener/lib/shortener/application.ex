defmodule Shortener.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      Plug.Cowboy.child_spec(scheme: :http, plug: Shortener.Router, options: [port: port()]),
      Shortener.LinkManager,
      Shortener.Storage,
      Shortener.Aggregates,
      Shortener.Cluster,
    ]

    opts = [strategy: :one_for_one, name: Shortener.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp port do
    name = Node.self()

    env =
      name
      |> Atom.to_string
      |> String.replace(~r/@.*$/, "")
      |> String.upcase

    name_specific_port = System.get_env("#{env}_PORT")
    specific_port = System.get_env("PORT")
    default_port = "4000"

    String.to_integer(name_specific_port || specific_port || default_port)
  end
end
