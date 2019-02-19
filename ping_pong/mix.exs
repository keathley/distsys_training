defmodule PingPong.MixProject do
  use Mix.Project

  def project do
    [
      app: :ping_pong,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:local_cluster, "~> 1.0", only: [:dev, :test]},
      {:schism, "~> 1.0", only: [:dev, :test]},
      {:propcheck, "~> 1.1", only: [:dev, :test]},
    ]
  end
end
