defmodule Shortener.MixProject do
  use Mix.Project

  def project do
    [
      app: :shortener,
      version: "0.1.0",
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Shortener.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug_cowboy, "~> 2.0"},
      {:redix, "~> 0.9"},
      {:httpoison, "~> 1.5"},
      {:drax, "~> 0.1"},
      {:ex_hash_ring, "~> 3.0"},
      {:libcluster, "~> 3.1"},
      {:local_cluster, "~> 1.0", only: [:dev, :test]},
      {:schism, "~> 1.0", only: [:dev, :test]},
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def aliases do
    [
      test: ["test --no-start --seed 0 --trace --max-failures 1"]
    ]
  end
end
