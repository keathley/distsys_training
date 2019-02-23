defmodule MapReduce.Worker do
  use GenServer

  alias MapReduce.{
    Master,
    Storage,
    WorkerRegistry,
    Master.WorkAssignment.Job,
  }

  require Logger

  defmodule Job do
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

  def map(name, job, f, reducer_count) do
    key = Job.map_name(name, job)
    {:ok, contents} = Storage.get(key)
    contents = contents || ""
    Logger.info("Worker.map: read split: #{job}, #{byte_size(contents)}")

    contents
    |> f.()
    |> Enum.group_by(fn map -> partition(name, job, map, reducer_count) end)
    |> Enum.map(fn {key, kv} -> {key, :erlang.term_to_binary(kv)} end)
    |> Enum.map(fn {key, kv} -> Storage.put(key, kv) end)

    job
  end

  def reduce(name, job, f, map_count) do
    Logger.info(fn -> "Worker.reduce: #{job}" end)

    kvs =
      (0..map_count)
      |> Enum.map(fn map_id -> Job.reduce_name(name, map_id, job) end)
      |> Enum.map(fn key -> Storage.get(key) end)
      |> Enum.map(fn {:ok, contents} -> contents end)
      |> Enum.reject(&is_nil/1)
      |> Enum.flat_map(&:erlang.binary_to_term/1)
      |> Enum.sort_by(fn kv -> kv[:key] end)
      |> Enum.group_by(fn kv -> kv[:key] end)
      # Spin through each group and hand them the key and a list of values
      |> Enum.map(fn {key, list} -> {key, f.(key, list)} end)
      |> Enum.map(fn {key, list} -> %{key: key, value: list} end)

    merge_key = Job.merge_name(name, job)
    Storage.put(merge_key, :erlang.term_to_binary(kvs))

    job
  end

  def merge(name, reduce_count) do
    Logger.info("Merging results...")

    name
    |> merge_names(reduce_count)
    |> Enum.map(fn key -> Storage.get(key) end)
    |> Enum.map(fn {:ok, result} -> result  end)
    |> Enum.reject(&is_nil/1)
    |> Enum.flat_map(&:erlang.binary_to_term/1)
    |> Enum.map(fn kv -> {kv.key, kv.value} end)
    |> Enum.into(Map.new())
  end

  defp merge_names(name, reduce_count) do
    (0..reduce_count)
    |> Enum.map(fn r -> Job.merge_name(name, r) end)
  end

  defp partition(job_id, map_id, map, reducer_count) do
    reducer =
      map.key
      |> :erlang.phash2
      |> Integer.mod(reducer_count)

    Job.reduce_name(job_id, map_id, reducer)
  end

  defp tap(coll, f) do
    Enum.map(coll, fn c ->
      f.(c)
      c
    end)
  end
end

