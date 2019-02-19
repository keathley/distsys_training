defmodule MapReduce.Storage do
  @pool_size 50

  def child_spec(opts) do
    opts = Keyword.merge([name: __MODULE__], opts)

    children =
      for i <- 0..(@pool_size-1) do
        Supervisor.child_spec({Redix, name: :"redix_#{i}"}, id: {Redix, i})
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

  def push(name \\ name(), key, value) do
    Redix.command(name, ["LPUSH", key, value])
  end

  def all(name \\ name(), key) do
    Redix.command(name, ["LRANGE", key, 0, -1])
  end

  def put(name \\ name(), key, value) do
    Redix.command(name, ["SET", key, value])
  end

  def get(name \\ name(), key) do
    Redix.command(name, ["GET", key])
  end

  def flush(name \\ name()) do
    Redix.command(name, ["FLUSHALL"])
  end

  defp name, do: :"redix_#{random_index()}"

  defp random_index() do
    rem(System.unique_integer([:positive]), @pool_size)
  end
end
