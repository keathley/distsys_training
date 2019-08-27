defmodule Shortener.TestUtils do
  def post(url, params) do
    headers = [
      {"Content-Type", "application/x-www-form-urlencoded"}
    ]
    HTTPoison.post!(url, URI.encode_query(params), headers)
  end

  def get(url) do
    HTTPoison.get!(url)
  end

  def eventually(f, retries \\ 0) do
    f.()
  rescue
    err ->
      if retries >= 10 do
        reraise err, __STACKTRACE__
      else
        :timer.sleep(500)
        eventually(f, retries + 1)
      end
  catch
    _exit, _term ->
      :timer.sleep(500)
      eventually(f, retries + 1)
  end
end
