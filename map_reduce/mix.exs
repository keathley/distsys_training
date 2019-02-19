defmodule MapReduce.MixProject do
  use Mix.Project

  def project do
    [
      app: :map_reduce,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {MapReduce.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:redix, "~> 0.9"},
      {:jason, "~> 1.1"},
    ]
  end
end
