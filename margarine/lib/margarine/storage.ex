defmodule Margarine.Storage do
  @pool_size 3

  def child_spec(_opts \\ []) do
    children =
      for i <- 0..(@pool_size-1) do
        Supervisor.child_spec(
          {Redix, database: database(), name: :"redix_#{i}"},
          id: {Redix, i})
      end

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
    case command(name, ["SET", key, value, "NX"]) do
      {:ok, "OK"} ->
        :ok

      {:ok, nil} ->
        {:error, :taken}
    end
  end

  def get(name \\ name(), key) do
    command(name, ["GET", key])
  end

  def flush(name \\ name()) do
    command(name, ["FLUSHDB"])
  end

  defp name, do: :"redix_#{random_index()}"

  defp random_index() do
    rem(System.unique_integer([:positive]), @pool_size)
  end

  defp database do
    Application.get_env(:linky, :redis_database)
  end
end
