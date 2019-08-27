defmodule Shortener.Aggregates do
  use GenServer

  alias __MODULE__
  alias Shortener.GCounter

  require Logger

  def count_for(table \\ __MODULE__, hash) do
    # TODO: Do lookup from ets in the client process
    0
  end

  def increment(server \\ __MODULE__, hash) do
    GenServer.cast(server, {:increment, hash})
  end

  def merge(server \\ __MODULE__, hash, counter) do
    GenServer.cast(server, {:merge, hash, counter})
  end

  def flush(server \\ __MODULE__) do
    GenServer.call(server, :flush)
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args \\ []) do
    # TODO: Monitor node connections and disconnects

    {:ok, %{table: __MODULE__, counters: %{}}}
  end

  def handle_cast({:increment, hash}, %{counters: counters}=data) do
    # TODO: Increment counter and broadcast a merge to the other nodes

    {:noreply, data}
  end

  def handle_cast({:merge, hash, counter}, data) do
    # TODO: Merge our existing set of counters with the new counter

    {:noreply, data}
  end

  def handle_call(:flush, _from, data) do
    :ets.delete_all_objects(data.table)
    {:reply, :ok, %{data | counters: %{}}}
  end

  def handle_info(msg, data) do
    # TODO - Handle node disconnects and reconnections
    Logger.info("Unhandled message: #{inspect msg}")

    {:noreply, data}
  end
end

