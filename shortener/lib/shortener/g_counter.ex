defmodule Shortener.GCounter do
  @moduledoc """
  This module defines a grow-only counter, CRDT.
  """

  @doc """
  Returns a new counter
  """
  def new(), do: nil

  @doc """
  Increments the counter for this node by the given delta. If this is the first
  increment operation for this node then the count defaults to the delta.
  """
  def increment(counter, node \\ Node.self(), delta \\ 1) when delta >= 0 do
    # TODO - Increment the counter for a given node.
  end

  @doc """
  Merges 2 counters together taking the highest value seen for each node.
  """
  def merge(c1, c2) do
    # TODO - Merge's 2 counter's together by taking the highest value seen
    # for each node.
  end

  @doc """
  Convert a counter to an integer.
  """
  def to_i(counter) do
    # TODO - Convert the counter into an integer
  end
end

