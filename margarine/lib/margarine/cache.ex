defmodule Margarine.Cache do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, [{:name, __MODULE__} | opts])
  end

  def lookup(cache \\ cache(), code) do
    # code goes here
  end

  def insert(cache \\ cache(), code, url) do
    # code goes here
  end

  def cache do
    GenServer.whereis(__MODULE__)
  end

  def flush do
    # the argument is the table name
    :ets.delete_all_objects()
  end

  def init(:ok) do
    state = create_table()
    {:ok, state}
  end

  defp create_table do
    # name table here
  end
end
