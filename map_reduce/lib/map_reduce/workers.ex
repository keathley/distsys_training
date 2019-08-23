defmodule MapReduce.Workers do
  @moduledoc """
  Provides an interface for starting and sending jobs to workers.
  """

  alias MapReduce.{
    Worker,
    WordCount,
  }

  @worker_sup MapReduce.WorkerSupervisor

  def child_spec(_args) do
    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: @worker_sup},
    ]

    %{
      id: __MODULE__,
      type: :supervisor,
      start: {Supervisor, :start_link, [children, [strategy: :one_for_one]]}
    }
  end

  def start_worker(node \\ Node.self(), manager_pid) do
    # TODO - Fill this in.
    DynamicSupervisor.start_child({@worker_sup, node}, {Worker, manager: manager_pid})
  end

  def run_job(worker, input, module \\ MapReduce.WordCount) do
    Worker.work(worker, input, module)
  end
end

