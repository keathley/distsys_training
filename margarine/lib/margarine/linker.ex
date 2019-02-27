defmodule Margarine.Linker do
  alias Margarine.{Cache, Storage}

  def lookup(hash) do
    code_key = code_key(hash)

    with {:ok, url} <- Cache.lookup(code_key) do
      {:ok, url}
    else
      {:error, :not_found} ->
        url = Storage.get(code_key)
        Cache.insert(code_key, url)
        url
    end
    |> case do
      {:ok, url} when not is_nil(url) ->
        {:ok, url}

      _ ->
        {:error, :not_found}
    end
  end

  def create(url, code) do
    code = hash_or_code(url, code)

    with :ok <- Storage.set(code_key(code), url),
         :ok <- Cache.insert(code_key(code), url) do
      {:ok, code}
    else
      err -> {:error, err}
    end
  end

  defp hash_or_code(_url, code) when not is_nil(code), do: code

  defp hash_or_code(url, _) do
    url
    |> md5
    |> Base.encode16(case: :lower)
    |> String.to_integer(16)
    |> pack_bitstring
    |> Base.url_encode64()
    |> String.replace(~r/==\n?/, "")
  end

  defp md5(str), do: :crypto.hash(:md5, str)

  defp pack_bitstring(int), do: <<int::big-unsigned-32>>

  defp code_key(code), do: "margarine:hash:#{code}"
end
