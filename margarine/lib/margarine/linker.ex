defmodule Margarine.Linker do
  alias Margarine.{Cache, Storage}

  def lookup(hash) do
    case Cache.lookup(code_key(hash)) do
      {:ok, url} ->
        {:ok, url}

      {:error, :not_found} ->
        case Storage.get(code_key(hash)) do
          {:ok, url} when not is_nil(url) ->
            Cache.insert(code_key(hash), url)
            {:ok, url}

          _ ->
            {:error, :not_found}
        end
    end
  end

  def create(url, code) do
    code = hash_or_code(url, code)

    Cache.insert(code_key(code), url)
    with :ok <- Storage.set(code_key(code), url) do
      {:ok, code}
    end
  end

  defp hash_or_code(_url, code) when not is_nil(code), do: code
  defp hash_or_code(url, _) do
    url
    |> md5
    |> Base.encode16(case: :lower)
    |> String.to_integer(16)
    |> pack_bitstring
    |> Base.url_encode64
    |> String.replace(~r/==\n?/, "")
  end

  defp md5(str), do: :crypto.hash(:md5, str)

  defp pack_bitstring(int), do: << int :: big-unsigned-32 >>

  defp code_key(code), do: "margarine:hash:#{code}"
end

