defmodule Margarine.MixProject do
  use Mix.Project

  def project do
    [
      app: :margarine,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Margarine.Application, []}
    ]
  end

  defp deps do
    [
      {:plug_cowboy, "~> 2.0"},
      {:redix, "~> 0.9"},
      {:httpoison, "~> 1.5"},
      {:local_cluster, "~> 1.0", only: [:dev, :test]},
      {:schism, "~> 1.0", only: [:dev, :test]}
    ]
  end

  defp aliases do
    [
      test: "test --no-start --trace --seed 0"
    ]
  end
end
