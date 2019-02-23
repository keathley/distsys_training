defmodule MapReduce do
  @moduledoc """
  Documentation for MapReduce.
  """

  alias MapReduce.{
    Job,
    Storage,
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

    receive do
      {:result, result} ->
        {:ok, result}
    end
  end

  def master(parent, mod, name, file) do
    us = self()

    FileUtil.split(name, file, @map_count)

    map_jobs    = for i <- 0..@map_count, do: i
    reduce_jobs = for i <- 0..@reduce_count, do: i

    for job <- map_jobs do
      spawn(fn ->
        ^job = Worker.map(name, job, &mod.map/1, @reduce_count)
        send(us, {:ok, :map, job})
      end)
    end
    :ok = collect_results(@map_count, :map, [])

    for job <- reduce_jobs do
      spawn(fn ->
        ^job = Worker.reduce(name, job, &mod.reduce/2, @map_count)
        send(us, {:ok, :reduce, job})
      end)
    end
    :ok = collect_results(@reduce_count, :reduce, [])

    result = Worker.merge(name, @reduce_count)
    send(parent, {:result, result})
  end

  def collect_results(count, _, acc) when length(acc) == count+1, do: :ok
  def collect_results(count, type, acc) do
    receive do
      {:ok, ^type, job_id} ->
        collect_results(count, type, [job_id | acc])
    end
  end
end

