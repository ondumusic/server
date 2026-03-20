# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :music_box,
  ecto_repos: [MusicBox.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configures the endpoint
config :music_box, MusicBoxWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: MusicBoxWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: MusicBox.PubSub,
  live_view: [signing_salt: "BRqOYVQb"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use new native JSON module for JSON parsing in Phoenix
config :phoenix, :json_library, JSON
config :ecto, :json_library, JSON
config :ecto_sqlite3, :json_library, JSON

config :music_box,
  extract_artwork_tool: MusicBox.Tool.ExtractArtwork,
  resize_artwork_tool: MusicBox.Tool.ResizeArtwork,
  transcode_tool: MusicBox.Tool.Transcode,
  probe_tool: MusicBox.Tool.Probe,
  cat_tool: MusicBox.Tool.Cat

config :music_box,
  web_enabled: true

config :music_box, MusicBox.Artwork,
  artwork_path: Path.absname("./tmp/artwork"),
  custom_api: nil,
  use_music_brainz: false

config :music_box, MusicBox.Transcoder,
  max_concurrency: 3,
  max_queue_size: 10,
  cache_impl: MusicBox.Transcoder.Cache.File,
  cache_path: Path.absname("./tmp/transcode")

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

# Import the local config if it exists
local = "#{config_env()}.local.exs"

if File.exists?(Path.expand(local, __DIR__)) do
  import_config local
end
