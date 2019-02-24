defmodule MapReduce do
  @moduledoc """
  Documentation for MapReduce.
  """

  alias MapReduce.{
    Worker,
    FileUtil,
  }

  require Logger

  @map_count 8
  @reduce_count 16

  alias MapReduce.WordCount

  @doc """
  Starts a new job with a name and input file
  """
  def start_job(mod \\ WordCount, name, file) do
    us = self()
    master = spawn(fn -> master(us, mod, name, file) end)

    for _ <- 0..8 do
      spawn(fn -> Worker.start(master) end)
    end

    receive do
      {:result, result} ->
        result
    end
  end

  def run(parent, mod, name, file) do
    master(parent, mod, name, file)
  end

  def master(parent, mod, name, file) do
    Logger.info("Starting master process")
    FileUtil.split(name, file, @map_count)

    map_jobs    = for i <- 0..@map_count, do: {:map, i}
    reduce_jobs = for i <- 0..@reduce_count, do: {:reduce, i}

    {:ok, workers} = assign_work(map_jobs, fn pid, job ->
      Worker.work(pid, name, job, &mod.map/1, @reduce_count)
    end)

    {:ok, _} = assign_work(reduce_jobs, [], [], workers, fn pid, job ->
      Worker.work(pid, name, job, &mod.reduce/2, @map_count)
    end)

    result = Worker.merge(name, @reduce_count)
    send(parent, {:result, result})
  end

  def assign_work(jobs, pending \\ [], completed \\ [], available_workers \\ [], f)
  def assign_work([], [], completed, workers, _) do
    {:ok, workers}
  end
  def assign_work(jobs, pending, completed, workers, f) do
    {jobs, pending, workers, assignments} = assign_idle_workers(jobs, pending, workers)

    for {worker, job} <- assignments, do: f.(worker, job)

    receive do
      {:ready, pid} ->
        assign_work(jobs, pending, completed, [pid | workers], f)

      {:finished, pid, job} ->
        assign_work(jobs, pending -- [job], [job | completed], [pid | workers], f)
    end
  end

  def assign_idle_workers(jobs, pending, workers, groups \\ [])
  def assign_idle_workers([], pending, workers, groups) do
    {[], pending, workers, groups}
  end
  def assign_idle_workers(jobs, pending, [], groups) do
    {jobs, pending, [], groups}
  end
  def assign_idle_workers([job | jobs], pending, [worker | workers], groups) do
    {jobs, [job | pending], workers, [{worker, job} | groups]}
  end

  def collect_results(count, _, acc) when length(acc) == count+1, do: :ok
  def collect_results(count, type, acc) do
    receive do
      {:ok, ^type, job_id} ->
        collect_results(count, type, [job_id | acc])
    end
  end
end

