defmodule MapReduce.Manager do
  @moduledoc """
  The manager is in charge of creating map-reduce jobs, starting workers,
  and distributing this work across the cluster.
  """
  use GenServer

  alias MapReduce.{
    FileUtil,
    Workers,
  }

  @initial %{
    workers: %{},
    caller: :none,
    pending_jobs: %{},
    finished_jobs: %{},
  }

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def start_job(server \\ __MODULE__, job) do
    GenServer.cast(server, {:start_job, job, self()})
  end

  def workers(server \\ __MODULE__) do
    GenServer.call(server, :get_workers)
  end

  def finished(server, results, worker) do
    GenServer.cast(server, {:finished, results, worker})
  end

  def worker_is_ready(server, worker_pid) do
    GenServer.cast(server, {:worker_is_ready, worker_pid})
  end

  def init(_args) do
    {:ok, @initial}
  end

  def handle_cast({:start_job, job, caller}, data) do
    jobs = FileUtil.chunk_file_into_jobs(job.input)

    for _i <- 0..job.num_workers do
      node = Enum.random([Node.self() | Node.list()])
      Workers.start_worker(node, self())
    end

    {:noreply, %{data | caller: caller, pending_jobs: jobs}}
  end

  def handle_cast({:worker_is_ready, worker_pid}, data) do
    # TODO - Keep track of workers readiness
    unless data.pending_jobs == %{} do
      job = Enum.random(data.pending_jobs)
      Workers.run_job(worker_pid, job)
    end

    {:noreply, %{data | workers: Map.put(data.workers, worker_pid, :ready)}}
  end

  def handle_cast({:finished, {job_id, results}, worker}, data) do
    # TODO - Mark job as done
    {_, pending_jobs} = Map.pop(data.pending_jobs, job_id)
    finished_jobs = Map.put(data.finished_jobs, job_id, results)

    # If we're out of pending jobs then we can bail out.
    if pending_jobs == %{} do
      counts =
        data.finished_jobs
        |> Enum.map(fn {_, rs} -> rs end)
        |> Enum.reduce(%{}, & Map.merge(&2, &1, fn _, v1, v2 -> v1 + v2 end))

      send(data.caller, {:results, counts})
      {:noreply, data}
    else
      job = Enum.random(pending_jobs)
      Workers.run_job(worker, job)

      new_data =
        data
        |> put_in([:workers, worker], :ready)
        |> put_in([:pending_jobs], pending_jobs)
        |> put_in([:finished_jobs], finished_jobs)

      {:noreply, new_data}
    end
  end

  def handle_call(:get_workers, _from, data) do
    # TODO - Return the workers that we know about
    # {:reply, [], data}
    {:reply, Map.keys(data.workers), data}
  end
end
