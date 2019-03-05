defmodule Margarine.Cache do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, [{:name, __MODULE__} | opts])
  end

  def lookup(cache \\ cache(), code) do
    case :ets.lookup(cache, code) do
      [{^code, url}] ->
        {:ok, url}

      _ ->
        {:error, :not_found}
    end
  end

  def insert(code, url) do
    for member <- :pg2.get_members(:cache) do
      GenServer.call(member, {:insert, code, url})
    end
  end

  def flush do
    :ok = GenServer.call(__MODULE__, :flush)
  end

  def init(:ok) do
    :pg2.join(:cache, self())
    table = create_table()
    {:ok, %{table: table}}
  end

  def handle_call(:flush, _from, state) do
    :ets.delete_all_objects(state.table)

    {:reply, :ok, state}
  end

  def handle_call({:insert, code, url}, _from, state) do
    :ets.insert(state.table, {code, url})

    {:reply, :ok, state}
  end

  def cache do
    __MODULE__
  end

  defp create_table do
    :ets.new(__MODULE__, [:set, :protected, :named_table])
  end
end
