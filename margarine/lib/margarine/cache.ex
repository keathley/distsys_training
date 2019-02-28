defmodule Margarine.Cache do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, [{:name, __MODULE__} | opts])
  end

  def lookup(cache \\ cache(), code) do
    GenServer.call(cache, {:lookup, code})
  end

  def insert(cache \\ cache(), code, url) do
    GenServer.call(cache, {:insert, code, url})
  end

  def cache do
    GenServer.whereis(__MODULE__)
  end

  def flush do
    :ets.delete_all_objects(:local_cache)
  end

  def init(:ok) do
    state = create_table()
    {:ok, state}
  end

  def handle_call({:lookup, code}, _from, state) do
    code =
      case :ets.lookup(:local_cache, code) do
        [] ->
          {:error, :not_found}

        code ->
          code =
            code
            |> List.first()
            |> elem(1)

          {:ok, code}
      end

    {:reply, code, state}
  end

  def handle_call({:insert, code, url}, _from, state) do
    res =
      case :ets.insert(:local_cache, {code, url}) do
        true -> :ok
        false -> :error
      end

    {:reply, res, state}
  end

  defp create_table do
    :ets.new(:local_cache, [:named_table, :public, :set])
  end
end
