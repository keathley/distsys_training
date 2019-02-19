defmodule MapReduce.Worker do
  use GenServer

  alias MapReduce.{
    Master,
    Storage,
    WorkerRegistry,
    Master.WorkAssignment.Job,
  }

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: via_tuple(args.id))
  end

  def map(worker_id, key, reducer_count) do
    GenServer.cast(via_tuple(worker_id), {:map, key, reducer_count})
  end

  def work(worker_id, job, worker_count) do
    case job.type do
      :map ->
        GenServer.cast(via_tuple(worker_id), {:map, job, worker_count})

      :reduce ->
        GenServer.cast(via_tuple(worker_id), {:reduce, job, worker_count})
    end
  end

  def reduce(worker_id, key, map_count) do
    GenServer.cast(via_tuple(worker_id), {:reduce, key, map_count})
  end

  def init(args) do
    {:ok, args, {:continue, :ready}}
  end

  def handle_continue(:ready, state) do
    Master.worker_ready(state.master, state.id)

    {:noreply, state}
  end

  def handle_cast({:map, job, reducer_count}, state) do
    key = Job.map_name(state.job_id, job.id)
    {:ok, contents} = Storage.get(key)
    contents = contents || ""
    Logger.info("Worker.map: read split: #{job.id}, #{byte_size(contents)}")

    contents
    |> state.module.map()
    |> Enum.group_by(fn map -> partition(state.job_id, job.id, map, reducer_count) end)
    |> Enum.map(fn {key, kv} -> {key, Jason.encode!(kv)} end)
    |> Enum.map(fn {key, kv} -> Storage.put(key, kv) end)

    :ok = Master.finish_map(state.master, job)

    {:noreply, state}
  end

  def handle_cast({:reduce, job, map_count}, state) do
    Logger.info(fn -> "Worker.reduce: #{job.id}" end)

    kvs =
      (0..map_count)
      |> Enum.map(fn map_id -> Job.reduce_name(state.job_id, map_id, job.id) end)
      |> Enum.map(fn key -> Storage.get(key) end)
      |> Enum.map(fn {:ok, contents} -> contents end)
      |> Enum.reject(&is_nil/1)
      |> Enum.flat_map(&Jason.decode!/1)
      |> Enum.sort_by(fn kv -> kv["key"] end)
      |> Enum.group_by(fn kv -> kv["key"] end)
      # Spin through each group and hand them the key and a list of values
      |> Enum.map(fn {key, list} -> {key, state.module.reduce(key, list)} end)
      |> Enum.map(fn {key, list} -> %{key: key, value: list} end)

    merge_key = Job.merge_name(state.job_id, job.id)
    Storage.put(merge_key, Jason.encode!(kvs))

    :ok = Master.finish_reduce(state.master, job)

    {:noreply, state}
  end

  defp partition(job_id, map_id, map, reducer_count) do
    reducer =
      map.key
      |> :erlang.phash2
      |> Integer.mod(reducer_count)

    Job.reduce_name(job_id, map_id, reducer)
  end

  def via_tuple(worker_id) do
    MapReduce.WorkerRegistry.via_tuple({__MODULE__, worker_id})
  end
end

