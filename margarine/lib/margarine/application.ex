defmodule Margarine.Application do
  @moduledoc false

  use Application
  # make sure to start the cache
  def start(_type, _args) do
    children = [
      Margarine.Storage,
      Plug.Cowboy.child_spec(scheme: :http, plug: Margarine.Router, options: [port: port()])
    ]

    opts = [strategy: :one_for_one, name: Margarine.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp port do
    name = Node.self()

    env =
      name
      |> Atom.to_string()
      |> String.replace(~r/@.*$/, "")
      |> String.upcase()

    # should be 4001
    String.to_integer(System.get_env("#{env}_PORT") || "4001")
  end
end
