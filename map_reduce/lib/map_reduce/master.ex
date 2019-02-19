defmodule MapReduce.Master do
  use GenServer

  alias MapReduce.{
    Storage,
    WorkerSupervisor,
    Worker,
    Master.WorkAssignment,
    Master.WorkAssignment.Job,
  }

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: via_tuple(args.job_id))
  end

  def finish_map(master, job) do
    GenServer.call(master, {:worker_finished, job})
  end

  def finish_reduce(master, job) do
    GenServer.call(master, {:worker_finished, job})
  end

  def worker_ready(master, worker_id) do
    GenServer.cast(master, {:worker_ready, worker_id})
  end

  def init(args) do
    map_count = 4
    reduce_count = 12

    workers = start_workers(args.module, args.job_id, 12)
    map_jobs = for i <- 0..map_count, do: {i, Job.new(:map, i)}
    reduce_jobs = for i <- 0..reduce_count, do: {i, Job.new(:reduce, i)}

    state =
      args
      |> Map.put(:map_count, map_count)
      |> Map.put(:reduce_count, reduce_count)
      |> Map.put(:map_jobs, Enum.into(map_jobs, Map.new()))
      |> Map.put(:reduce_jobs, Enum.into(reduce_jobs, Map.new()))
      |> Map.put(:workers, workers)
      |> Map.put(:state, :map)

    {:ok, state, {:continue, :run}}
  end

  defp start_workers(module, job_id, count) do
    for i <- 0..count, name="job-#{job_id}-worker-#{i}" do
      {:ok, _} = WorkerSupervisor.start_worker(module, name, self(), job_id)
      name
    end
  end

  def handle_continue(:run, state) do
    split(state)

    {:noreply, state}
  end

  def handle_cast({:worker_ready, worker_id}, state) do
    case WorkAssignment.next_job(state) do
      nil ->
        {:noreply, state}

      job ->
        state = WorkAssignment.assign_job_to_worker(state, job, worker_id)
        Worker.work(worker_id, job, state.reduce_count)
        {:noreply, state}
    end
  end

  def handle_cast(:merge_results, state) do
    Logger.info("Merging results...")

    merged =
      state
      |> merge_names
      |> Enum.map(fn key -> Storage.get(key) end)
      |> Enum.map(fn {:ok, result} -> result  end)
      |> Enum.reject(&is_nil/1)
      |> Enum.flat_map(&Jason.decode!/1)
      |> Enum.map(fn kv -> {kv["key"], kv["value"]} end)
      |> Enum.into(Map.new())

    send(state.client, {:ok, merged})

    {:noreply, state}
  end

  def handle_call({:worker_finished, job}, _from, state) do
    Logger.debug("Job finished: #{job.id}")
    state = WorkAssignment.finish_job(state, job)

    if WorkAssignment.finished_working?(state) do
      GenServer.cast(self(), :merge_results)
      {:reply, :ok, state}
    else
      state = WorkAssignment.assign_jobs(state, state.state, fn {worker, job} ->
        Worker.work(worker, job, state.map_count)
      end)

      {:reply, :ok, state}
    end
  end

  defp merge_names(state) do
    (0..state.reduce_count)
    |> Enum.map(fn r -> Job.merge_name(state.job_id, r) end)
  end

  defp split(state) do
    tmp = System.tmp_dir!()
    stats = File.stat!(state.input_file)
    split_size = trunc(stats.size / state.map_count)
    split_keys = for i <- 0..state.map_count, do: Job.map_name(state.job_id, i)

    chunk_fn = fn item, {l, acc} ->
      if l > split_size do
        {:cont, acc <> item, {0, ""}}
      else
        {:cont, {l+byte_size(item), acc<>item}}
      end
    end

    after_fn = fn
      {0, ""} -> {:cont, {0, ""}}
      {_, acc} -> {:cont, acc, {0, ""}}
    end

    chunks_with_keys =
      state.input_file
      |> File.stream!
      |> Stream.chunk_while({0, ""}, chunk_fn, after_fn)
      |> Stream.zip(split_keys)

    chunks_with_keys
    |> Enum.each(fn {chunk, key} -> Storage.put(key, chunk) end)

    chunks_with_keys
    |> Enum.map(fn {_, key} -> key end)
  end

  defp update_count({word, count}, map) do
    Map.update(map, word, count, & &1+count)
  end

  defp via_tuple(job_id), do: :"#{job_id}"
end

