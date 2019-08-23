defmodule MapReduce.WordCount do
  @typedoc """
  KV provides an intermediate format for all of our mapped data
  """
  import Norm

  def output_spec, do: spec(
    is_map() and
    fn m -> Enum.all?(Map.keys(m), & is_binary(&1)) end and
    fn m -> Enum.all?(Map.values(m), & is_integer(&1)) end
  )

  @spec process(String.t()) :: %{}
  def process(value) do
    # TODO - Your code goes here...
    value
    |> conform!(spec(is_binary()))
    |> String.split(" ")
    |> Enum.map(& {&1, 1})
    |> Enum.group_by(fn {k, _} -> k end, fn {_, v} -> v end)
    |> Enum.map(fn {k, counts} -> {k, Enum.sum(counts)} end)
    |> Enum.into(%{})
    |> conform!(output_spec())
  end
end
