defmodule Margarine.Pg2 do
  use GenServer
  alias Margarine.Linker

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, [{:name, __MODULE__} | opts])
  end

  def broadcast(code, url) do
    Enum.map(:pg2.get_members(:margarine), fn pid ->
      send(pid, {:broadcast, code, url})
    end)
  end

  def cache do
    GenServer.whereis(__MODULE__)
  end

  def init(:ok) do
    state = :pg2.join(:margarine, self())
    {:ok, state}
  end

  def handle_info({:broadcast, code, url}, state) do
    code = Linker.hash_or_code(url, nil)

    case Margarine.Linker.lookup(code) do
      {:ok, _url} -> :ok
      _ -> Margarine.Linker.create(code, url)
    end

    {:noreply, state}
  end
end
