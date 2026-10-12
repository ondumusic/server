# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :ondu,
  ecto_repos: [Ondu.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configures the endpoint
config :ondu, OnduWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: OnduWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Ondu.PubSub,
  live_view: [signing_salt: "BRqOYVQb"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use new native JSON module for JSON parsing in Phoenix
config :phoenix, :json_library, JSON

# Keeps e.g. the session token of socket connections out of the logs.
config :phoenix, :filter_parameters, ["password", "token", "Token"]
config :ecto, :json_library, JSON
config :ecto_sqlite3, :json_library, JSON

config :ex_aws,
  http_client: Ondu.AWSReqClient,
  json_codec: JSON,
  region: {:system, "AWS_REGION"}

config :ondu,
  extract_artwork_tool: Ondu.Tool.ExtractArtwork,
  resize_artwork_tool: Ondu.Tool.ResizeArtwork,
  transcode_tool: Ondu.Tool.Transcode,
  probe_tool: Ondu.Tool.Probe,
  loudness_tool: Ondu.Tool.Loudness

config :ondu,
  storage_impl: Ondu.Storage.File

config :ondu,
  web_enabled: true,
  docs_enabled: true

config :ondu, Ondu.Artwork, artwork_path: Path.absname("./tmp/artwork")

config :ondu, Ondu.Transcoder,
  max_concurrency: 3,
  max_queue_size: 10,
  cache_path: Path.absname("./tmp/transcode"),
  max_cache_size: 10 * 1024 * 1024 * 1024

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

# Import the local config if it exists
local = "#{config_env()}.local.exs"

if File.exists?(Path.expand(local, __DIR__)) do
  import_config local
end
