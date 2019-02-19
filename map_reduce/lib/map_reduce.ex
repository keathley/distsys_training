defmodule MapReduce do
  @moduledoc """
  Documentation for MapReduce.
  """

  alias MapReduce.WordCount

  @doc """
  Starts a new job with a name and input file
  """
  def start_job(mod \\ WordCount, name, file) do
    args = %{
      module: mod,
      job_id: name,
      input_file: file,
      client: self(),
    }

    {:ok, _master} = MapReduce.Master.start_link(args)
    # MapReduce.Master.wait(name)

    receive do
      {:ok, results} ->
        {:ok, results}
    end
  end
end

