# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :margarine,
  redis_database: 0

config :logger,
  level: :debug

import_config "#{Mix.env()}.exs"
