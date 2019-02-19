defmodule MapReduce.Job do
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args)
  end

  @impl true
  def init(args) do
    children = [
      {MapReduce.Master, args},
      MapReduce.WorkerRegistry,
      MapReduce.WorkerSupervisor,
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
