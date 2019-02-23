defmodule MapReduce.FileUtil do
  require Logger

  alias MapReduce.Storage
  alias MapReduce.Worker.Job

  def split(name, file, map_count) do
    tmp = System.tmp_dir!()
    stats = File.stat!(file)
    split_size = trunc(stats.size / map_count)
    Logger.info("Splitting input file into #{split_size} chunks")

    split_keys = for i <- 0..map_count, do: Job.map_name(name, i)

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
      file
      |> File.stream!
      |> Stream.chunk_while({0, ""}, chunk_fn, after_fn)
      |> Stream.zip(split_keys)

    chunks_with_keys
    |> Enum.each(fn {chunk, key} -> Storage.put(key, chunk) end)

    chunks_with_keys
    |> Enum.map(fn {_, key} -> key end)
  end
end

