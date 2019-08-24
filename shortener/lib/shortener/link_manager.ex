defmodule Shortener.LinkManager do
  @moduledoc """
  Manages the lifecycles of links
  """

  alias Shortener.Storage
  alias Shortener.LinkManager.Cache
  alias Shortener.Cluster

  @lookup_sup __MODULE__.LookupSupervisor

  def child_spec(_args) do
    children = [
      Cache,
      {Task.Supervisor, strategy: :one_for_one, name: @lookup_sup}
    ]

    %{
      id: __MODULE__,
      type: :supervisor,
      start: {Supervisor, :start_link, [children, [strategy: :one_for_one]]}
    }
  end

  def create(url) do
    short_code = generate_short_code(url)
    :ok = Storage.set(short_code, url)
    node = Cluster.find_node(short_code)
    :ok = Cache.insert({Cache, node}, short_code, url)

    {:ok, short_code}
  catch
    :exit, _ ->
      {:error, :node_down}
  end

  def lookup(short_code) do
    case Cache.lookup(Cache, short_code) do
      {:error, :not_found} ->
        case Storage.get(short_code) do
          {:ok, url} ->
            Cache.insert(short_code, url)
            {:ok, url}

          error ->
            error
        end

      {:ok, url} -> {:ok, url}
    end
  end

  def remote_lookup(short_code) do
    node = Cluster.find_node(short_code)
    task = Task.Supervisor.async({@lookup_sup, node}, __MODULE__, :lookup, [short_code])
    Task.await(task, 50)
  catch
    :exit, _ ->
      {:error, :node_down}
  end

  def generate_short_code(url) do
    url
    |> hash
    |> Base.encode16(case: :lower)
    |> String.to_integer(16)
    |> pack_bitstring
    |> Base.url_encode64
    |> String.replace(~r/==\n?/, "")
  end

  defp hash(str), do: :crypto.hash(:sha256, str)

  defp pack_bitstring(int), do: << int :: big-unsigned-32 >>
end
