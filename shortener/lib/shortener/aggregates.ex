defmodule Shortener.Aggregates do
  use GenServer

  alias __MODULE__
  alias Shortener.GCounter

  require Logger

  def count_for(table \\ __MODULE__, hash) do
    # TODO: Do lookup from ets in the client process
    # 0
    case :ets.lookup(table, hash) do
      [] ->
        0

      [{^hash, count}] ->
        count
    end
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
    # TODO: Join pg2 group
    # TODO: Monitor node connections and disconnects
    :pg2.create("aggregates")
    :pg2.join("aggregates", self())
    __MODULE__ = :ets.new(__MODULE__, [:named_table, :set, :protected])
    :net_kernel.monitor_nodes(true)

    {:ok, %{table: __MODULE__, counters: %{}}}
  end

  def handle_cast({:increment, hash}, %{counters: counters}=data) do
    # TODO: Increment counter here using our `Node.self()` id as the key
    #
    # :ets.insert(state.table, {hash, counter})
    # Broadcast messages to other nodes

    counter = GCounter.increment(counters[hash] || GCounter.new())
    new_counters = Map.put(counters, hash, counter)
    new_count = GCounter.to_i(counter)
    :ets.insert(data.table, {hash, new_count})

    GenServer.abcast(Node.list(), __MODULE__, {:merge, hash, counter})

    {:noreply, %{data | counters: new_counters}}
  end

  def handle_cast({:merge, hash, counter}, data) do
    # TODO: Merge our existing set of counters with the new counter
    our_counter = data.counters[hash] || counter
    new_counter = GCounter.merge(our_counter, counter)
    new_count = GCounter.to_i(new_counter)
    new_counters = Map.put(data.counters, hash, new_counter)
    :ets.insert(data.table, {hash, new_count})

    {:noreply, %{data | counters: new_counters}}
  end

  def handle_call(:flush, _from, data) do
    :ets.delete_all_objects(data.table)
    {:reply, :ok, %{data | counters: %{}}}
  end

  def handle_info({:nodeup, n}, data) do
    for {hash, counter} <- data.counters do
      Aggregates.merge({Aggregates, n}, hash, counter)
    end

    {:noreply, data}
  end

  def handle_info(msg, data) do
    # TODO - Handle node disconnects and reconnections
    Logger.info("Unhandled message: #{inspect msg}")

    {:noreply, data}
  end

  defp get_counter(table, hash) do
    case :ets.lookup(table, hash) do
      [{^hash, aggregates}] ->
        aggregates

      _ ->
        # TODO: Create a new counter
    end
  end
end

