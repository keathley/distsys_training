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
    :aggregates
    |> :pg2.get_members()
    |> Enum.map(fn pid -> GenServer.cast(pid, {:increment, hash}) end)
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args \\ []) do
    __MODULE__ = :ets.new(__MODULE__, [:set, :named_table, :protected])
    :pg2.join(:aggregates, self())

    {:ok, %{table: __MODULE__}}
  end

  def handle_cast({:increment, hash}, state) do
    case :ets.lookup(state.table, hash) do
      [{^hash, counter}] ->
        updated = GCounter.increment(counter)
        :ets.insert(state.table, {hash, updated})

      _ ->
        counter = GCounter.increment(GCounter.new())
        :ets.insert(state.table, {hash, counter})
    end

    {:noreply, state}
  end
end

