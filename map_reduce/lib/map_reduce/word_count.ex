defmodule MapReduce.WordCount do
  @typedef """
  KV provides an intermediate format for all of our mapped data
  """
  @type kv :: %{key: String.t, value: term()}

  @spec map(String.t) :: [kv()]
  def map(value) do
    # Your code goes here...
  end

  @spec reduce(String.t, [kv()]) :: term()
  def reduce(key, list) do
    # Your code goes here
  end
end
