defmodule MapReduce.Master.WorkAssignment do
  defmodule Job do
    defstruct [:type, :id, :worker_id, :status]

    @type status :: :pending
                  | :working
                  | :completed

    def new(type, id) do
      %{type: type, id: id, worker_id: nil, status: :pending}
    end

    def merge_name(job_id, reduce_job) do
      "mrjob-#{job_id}-res-#{reduce_job}"
    end

    def map_name(job_id, map_job_id) do
      "mrjob-#{job_id}-#{map_job_id}"
    end

    def reduce_name(job_id, map_job_id, reduce_job) do
      "#{map_name(job_id, map_job_id)}-#{reduce_job}"
    end
  end

  def finish_job(state, job) do
    state =
      state
      |> put_in([:"#{state.state}_jobs", job.id, :status], :completed)
      |> put_in([:"#{state.state}_jobs", job.id, :worker_id], nil)

    if state.state == :map && mapping_completed?(state) do
      %{state | state: :reduce}
    else
      state
    end
  end

  def finished_working?(state) do
    IO.puts "Checking to see if we're done reducing"
    state.reduce_jobs
    |> Map.values
    |> Enum.all?(fn job -> job.status == :completed end)
  end

  def pending_jobs(state, :reduce) do
    state.reduce_jobs
    |> Map.values
    |> Enum.filter(fn job -> job.status == :pending end)
  end

  def next_job(state) do
    if mapping?(state) do
      state.map_jobs
      |> Enum.map(fn {_, job} -> job end)
      |> Enum.find(fn job -> job.status == :pending end)
    else
      state.reduce_jobs
      |> Enum.map(fn {_, job} -> job end)
      |> Enum.find(fn job -> job.status == :pending end)
    end
  end

  def mapping?(state) do
    state.map_jobs
    |> Map.values
    |> Enum.any?(fn %{status: status} -> status in [:working, :pending] end)
  end

  def mapping_completed?(state) do
    state.map_jobs
    |> Map.values
    |> Enum.all?(fn %{status: status} -> status == :completed end)
  end

  def assign_job_to_worker(state, job, worker_id) do
    state
    |> put_in([:map_jobs, job.id, :worker_id], worker_id)
    |> put_in([:map_jobs, job.id, :status], :working)
  end

  def assign_map_jobs(%{map_workers: workers, map_jobs: jobs}=state) do
    idle_workers =
      workers
      |> Enum.reject(fn worker -> worker in busy_workers(jobs) end)

    jobs_to_run = for worker <- idle_workers, job <- pending_jobs(jobs) do
      {worker, job}
    end

    jobs = Enum.reduce jobs_to_run, state.map_jobs, fn {worker_id, job_id}, jobs  ->
      jobs
      |> put_in([job_id, :status], :working)
      |> put_in([job_id, :worker_id], worker_id)
    end

    new_state = %{state | map_jobs: jobs}

    {new_state, jobs_to_run}
  end

  def finish_map(%{map_jobs: jobs}=state, job) do
    %{state | map_jobs: Map.update(jobs, job.id, & Map.put(&1, :status, :completed))}
  end

  def assign_jobs(state, :map, f) do
    assign_job(Map.values(state.map_jobs), state.workers, f, state)
  end

  def assign_jobs(state, :reduce, f) do
    assign_job(Map.values(state.reduce_jobs), state.workers, f, state)
  end

  defp assign_job([], _, _f, new_state), do: new_state
  defp assign_job(_, [], _f, new_state), do: new_state
  defp assign_job([job | jobs], [worker | workers], f, state) do
    if job.status == :pending do
      f.({worker, job})

      updated_job = %{job | worker_id: worker, status: :working}
      new_state =
        state
        |> put_in([:reduce_jobs, job.id], updated_job)

      assign_job(jobs, workers, f, new_state)
    else
      assign_job(jobs, [worker | workers], f, state)
    end
  end

  defp busy_workers(jobs) do
    jobs
    |> Map.values
    |> Enum.filter(fn %{status: status} -> status == :working end)
    |> Enum.map(fn job -> job.worker_id end)
  end

  def idle_workers(state, :reduce) do
    busy = busy_workers(state.reduce_jobs)

    state.reduce_workers
    |> Enum.reject(fn worker -> worker in busy end)
  end

  defp pending_jobs(jobs) do
    jobs
    |> Map.values
    |> Enum.filter(fn %{status: status} -> status == :pending end)
  end

  def finished_mapping?(%{map_jobs: jobs}) do
    jobs
    |> Map.values
    |> Enum.all?(fn status -> status == :completed end)
  end
end

