# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
import Config

config :shortener,
  redis_database: 0

config :logger,
  level: :info

import_config "#{Mix.env()}.exs"
