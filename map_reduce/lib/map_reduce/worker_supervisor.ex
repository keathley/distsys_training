defmodule MapReduce.WorkerSupervisor do
  use DynamicSupervisor

  def start_link(args) do
    DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def start_worker(module, name, master, job_id) do
    args = %{
      module: module,
      id: name,
      master: master,
      job_id: job_id,
    }
    DynamicSupervisor.start_child(__MODULE__, {MapReduce.Worker, args})
  end

  @impl true
  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end

