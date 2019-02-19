defmodule MapReduce.WordCount do
  # @behaviour MapReduce.Job
  def map(value) do
    value
    |> String.split(~r/\W/, trim: true)
    |> Enum.map(fn word -> %{key: word, value: 1} end)
  end

  # @impl true
  def reduce(_key, list) do
    list
    |> Enum.map(fn kv -> kv["value"] end)
    |> Enum.sum
  end
end

