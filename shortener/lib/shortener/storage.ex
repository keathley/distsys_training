defmodule Shortener.Storage do
  @pool_size 3

  def child_spec(_opts \\ []) do
    children = [
      {Redix, database: database(), name: __MODULE__}
    ]

    %{
      id: __MODULE__,
      type: :supervisor,
      start: {Supervisor, :start_link, [children, [strategy: :one_for_one]]},
    }
  end

  def command(name \\ name(), cmds) when is_list(cmds) do
    Redix.command(name, cmds)
  end

  def set(name \\ name(), key, value) do
    with {:ok, _} <- command(name, ["SET", key, value, "NX"]) do
      :ok
    end
  end

  def get(name \\ name(), key) do
    command(name, ["GET", key])
  end

  def flush(name \\ name()) do
    command(name, ["FLUSHDB"])
  end

  defp name, do: __MODULE__

  defp database do
    Application.get_env(:shortener, :redis_database)
  end
end
