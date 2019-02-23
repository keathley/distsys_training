defmodule MapReduce.WordCount do
  @typedoc """
  KV provides an intermediate format for all of our mapped data
  """
  @type kv :: %{key: String.t, value: term()}

  @spec map(String.t) :: [kv()]
  def map(value) do
    # Your code goes here...
    value
    |> String.split(~r/\W/, trim: true)
    |> Enum.map(fn word -> %{key: word, value: 1} end)
  end

  @spec reduce(String.t, [kv()]) :: term()
  def reduce(_key, list) do
    # Your code goes here
    list
    |> Enum.map(fn kv -> kv.value end)
    |> Enum.sum
  end
end
