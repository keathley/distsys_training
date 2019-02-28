defmodule Margarine.Aggregates do
  use GenServer

  require Logger

  def for(hash) do
    # TODO: Do lookup from ets in the client process
    {:error, :not_found}
  end

  def increment(hash) do
    GenServer.cast(__MODULE__, {:increment, hash})
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args \\ []) do
    # TODO: Join pg2 group
    __MODULE__ = :ets.new(__MODULE__, [:named_table, :set, :protected])
    :net_kernel.monitor_nodes(true)

    {:ok, %{table: __MODULE__}}
  end

  def handle_cast({:increment, hash}, state) do
    counter = get_counter(state.table, hash)

    # TODO: Increment counter here using our `Node.self()` id as the key

    :ets.insert(state.table, {hash, counter})
    # Broadcast messages to other nodes

    {:noreply, state}
  end

  def handle_cast({:merge, counter}, state) do
    # TODO: Pull counter from our ets table and merge it with the given counter
    # then store it back in ets

    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.info("Unhandled message: #{inspect msg}")
    {:noreply, state}
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

