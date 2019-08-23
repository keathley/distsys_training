defmodule MapReduce.FileUtil do
  require Logger

  alias MapReduce.Worker.Job

  def chunk_file_into_jobs(file) do
    stats = File.stat!(file)
    split_size = trunc(stats.size / 8)
    Logger.info("Splitting input file into #{split_size} chunks")

    split_keys = for i <- 0..200, do: i

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

    file
    |> File.stream!
    |> Stream.chunk_while({0, ""}, chunk_fn, after_fn)
    |> Stream.zip(split_keys)
    |> Stream.map(fn {data, key} -> {key, data} end)
    |> Enum.into(%{})
  end
end
