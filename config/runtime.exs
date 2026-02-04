import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/music_box start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :music_box, MusicBoxWeb.Endpoint, server: true
end

config :music_box, MusicBox.Repo,
  journal_mode: :wal,
  temp_store: :memory,
  cache_size: 64_000

config :music_box, MusicBox.FileScanner.Repo,
  journal_mode: :wal,
  temp_store: :memory,
  cache_size: 64_000

if config_env() == :prod do
  music_box_uri =
    System.get_env("MB_URL") ||
      raise """
      environment variable MB_URL is missing.
      For example: https://music.example.com/
      """

  music_box_uri = URI.parse(music_box_uri)

  database_path =
    System.get_env("DATABASE_PATH") ||
      raise """
      environment variable DATABASE_PATH is missing.
      For example: /etc/music_box/music_box.db
      """

  transcode_cache_path =
    System.get_env("TRANSCODE_CACHE_PATH") ||
      raise """
      environment variable TRANSCODE_CACHE_PATH is missing.
      For example: /tmp/transcode-cache/
      """

  artwork_path =
    System.get_env("ARTWORK_PATH") ||
      raise """
      environment variable ARTWORK_PATH is missing.
      For example: /tmp/artwork/
      """

  config :music_box, MusicBox.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")

  config :music_box, MusicBox.Transcoder,
    artwork_path: artwork_path,
    cache_path: transcode_cache_path

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  config :music_box, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :music_box, MusicBoxWeb.Endpoint,
    url: [host: music_box_uri.host, port: music_box_uri.port, scheme: music_box_uri.scheme],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: 4000
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :music_box, MusicBoxWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :music_box, MusicBoxWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end
