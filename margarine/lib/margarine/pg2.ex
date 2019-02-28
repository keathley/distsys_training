defmodule Margarine.Pg2 do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, [{:name, __MODULE__} | opts])
  end

  def broadcast(code, url) do
    # code here
  end

  def cache do
    GenServer.whereis(__MODULE__)
  end

  def init(:ok) do
  end

  def handle_info({:broadcast, code, url}, state) do
    # code here
  end
end
