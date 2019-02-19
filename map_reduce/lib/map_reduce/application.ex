defmodule MapReduce.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      MapReduce.Storage,
      MapReduce.WorkerRegistry,
      MapReduce.WorkerSupervisor,
      # MapReduce.JobRegistry,
      # MapReduce.JobSupervisor,
    ]

    opts = [
      strategy: :one_for_one
    ]

    Supervisor.start_link(children, opts)
  end
end

