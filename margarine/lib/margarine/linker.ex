defmodule Margarine.Linker do
  alias Margarine.Cache

  def lookup(hash) do
    with {:ok, url} <- Cache.lookup(code_key(hash)) do
      {:ok, url}
    else
      _ ->
        {:error, :not_found}
    end
  end

  def create(url, code) do
    code = hash_or_code(url, code)

    with :ok <- Cache.insert(code_key(code), url) do
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
    |> Base.url_encode64()
    |> String.replace(~r/==\n?/, "")
  end

  defp md5(str), do: :crypto.hash(:md5, str)

  defp pack_bitstring(int), do: <<int::big-unsigned-32>>

  defp code_key(code), do: "margarine:hash:#{code}"
end
