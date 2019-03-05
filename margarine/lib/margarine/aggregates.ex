defmodule Margarine.Aggregates do
  use GenServer

  alias Drax.GCounter

  def for(hash) do
    case :ets.lookup(__MODULE__, hash) do
      [{^hash, counter}] ->
        {:ok, GCounter.to_i(counter)}

      _ ->
        {:error, :not_found}
    end
  end

  def increment(hash) do
    GenServer.cast(__MODULE__, {:increment, hash})
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args \\ []) do
    :net_kernel.monitor_nodes(true)
    __MODULE__ = :ets.new(__MODULE__, [:set, :named_table, :protected])
    :pg2.join(:aggregates, self())

    {:ok, %{table: __MODULE__, nodes: []}}
  end

  def handle_cast({:increment, hash}, state) do
    counter = get_counter(state.table, hash)
    counter = GCounter.increment(counter, Node.self())
    :ets.insert(state.table, {hash, counter})
    members = :pg2.get_members(:aggregates)

    for member <- members do
      GenServer.cast(member, {:merge, {hash, counter}})
    end

    {:noreply, state}
  end

  def handle_cast({:merge, {hash, c1}}, state) do
    c2 = get_counter(state.table, hash)
    merged = GCounter.merge(c2, c1)
    :ets.insert(state.table, {hash, merged})

    {:noreply, state}
  end

  def handle_info({:nodeup, node}, state) do
    counters = :ets.tab2list(state.table)

    # This works
    for counter <- counters do
      GenServer.cast({__MODULE__, node}, {:merge, counter})
    end

    # This doesn't
    # for member <- :pg2.get_members(:aggregates), counter <- counters do
    #   GenServer.cast(member, {:merge, counter})
    # end

    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp get_counter(table, hash) do
    case :ets.lookup(table, hash) do
      [{^hash, counter}] ->
        counter

      _ ->
        GCounter.new()
    end
  end
end

