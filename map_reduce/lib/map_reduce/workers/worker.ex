defmodule MapReduce.Worker do
  use GenServer

  alias MapReduce.Manager

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def work(server, job, module) do
    GenServer.cast(server, {:work, job, module})
  end

  def init(args) do
    data = %{
      manager: Keyword.fetch!(args, :manager),
    }

    Manager.worker_is_ready(data.manager, self())
    {:ok, data}
  end

  def handle_cast({:work, {job_id, input}, module}, data) do
    results = module.process(input)
    Manager.finished(data.manager, {job_id, results}, self())
    {:noreply, data}
  end
end

  # alias MapReduce.Storage

  # require Logger

  # defmodule Job do
  #   def merge_name(job_id, reduce_job) do
  #     "mrjob-#{job_id}-res-#{reduce_job}"
  #   end

  #   def map_name(job_id, map_job_id) do
  #     "mrjob-#{job_id}-#{map_job_id}"
  #   end

  #   def reduce_name(job_id, map_job_id, reduce_job) do
  #     "#{map_name(job_id, map_job_id)}-#{reduce_job}"
  #   end
  # end

  # def start(master, total_jobs \\ -1) do
  #   send(master, {:ready, self()})
  #   do_work(master, total_jobs)
  # end

  # def work(worker, name, job, f, other_count) do
  #   send(worker, {name, job, f, other_count})
  # end

  # def do_work(master, 0) do
  #   Logger.error("Worker is terminating")
  #   :ok
  # end
  # def do_work(master, total_jobs) do
  #   receive do
  #     {name, {type, job}, f, other_count} ->
  #       case type do
  #         :map    -> do_map(name, job, f, other_count)
  #         :reduce -> do_reduce(name, job, f, other_count)
  #       end
  #       send(master, {:finished, self(), {type, job}})
  #       result = Storage.incr(:erlang.term_to_binary(self()))
  #   end

  #   do_work(master, total_jobs-1)
  # end

  # def do_map(name, job, f, reducer_count) do
  #   key = Job.map_name(name, job)
  #   {:ok, contents} = Storage.get(key)
  #   contents = contents || ""
  #   Logger.info("Worker.map: read split: #{job}, #{byte_size(contents)}")

  #   contents
  #   |> f.()
  #   |> Enum.group_by(fn map -> partition(name, job, map, reducer_count) end)
  #   |> Enum.map(fn {key, kv} -> {key, :erlang.term_to_binary(kv)} end)
  #   |> Enum.map(fn {key, kv} -> Storage.put(key, kv) end)
  # end

  # def do_reduce(name, job, f, map_count) do
  #   Logger.info(fn -> "Worker.reduce: #{job}" end)

  #   kvs =
  #     (0..map_count)
  #     |> Enum.map(fn map_id -> Job.reduce_name(name, map_id, job) end)
  #     |> Enum.map(fn key -> Storage.get(key) end)
  #     |> Enum.map(fn {:ok, contents} -> contents end)
  #     |> Enum.reject(&is_nil/1)
  #     |> Enum.flat_map(&:erlang.binary_to_term/1)
  #     |> Enum.sort_by(fn kv -> kv[:key] end)
  #     |> Enum.group_by(fn kv -> kv[:key] end)
  #     # Spin through each group and hand them the key and a list of values
  #     |> Enum.map(fn {key, list} -> {key, f.(key, list)} end)
  #     |> Enum.map(fn {key, list} -> %{key: key, value: list} end)

  #   merge_key = Job.merge_name(name, job)
  #   Storage.put(merge_key, :erlang.term_to_binary(kvs))
  # end

  # def merge(name, reduce_count) do
  #   Logger.info("Merging results...")

  #   name
  #   |> merge_names(reduce_count)
  #   |> Enum.map(fn key -> Storage.get(key) end)
  #   |> Enum.map(fn {:ok, result} -> result  end)
  #   |> Enum.reject(&is_nil/1)
  #   |> Enum.flat_map(&:erlang.binary_to_term/1)
  #   |> Enum.map(fn kv -> {kv.key, kv.value} end)
  #   |> Enum.into(Map.new())
  # end

  # defp merge_names(name, reduce_count) do
  #   (0..reduce_count)
  #   |> Enum.map(fn r -> Job.merge_name(name, r) end)
  # end

  # defp partition(job_id, map_id, map, reducer_count) do
  #   reducer =
  #     map.key
  #     |> :erlang.phash2
  #     |> Integer.mod(reducer_count)

  #   Job.reduce_name(job_id, map_id, reducer)
  # end
# end

