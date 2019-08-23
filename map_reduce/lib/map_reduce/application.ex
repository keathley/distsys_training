defmodule MapReduce.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # MapReduce.Storage,
      MapReduce.Workers,
      MapReduce.Manager,
    ]

    opts = [
      strategy: :one_for_one
    ]

    Supervisor.start_link(children, opts)
  end
end

