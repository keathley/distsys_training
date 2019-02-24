defmodule MapReduce.Identity do
  def map(value) do
    value
    |> String.split
    |> Enum.map(fn word -> %{key: word, value: ""} end)
  end

  def reduce(_key, _list) do
    ""
  end
end
