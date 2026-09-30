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
  default_transaction_mode: :immediate,
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

  if is_nil(music_box_uri.scheme) do
    raise "MB_URL is missing scheme (example value: https://example.com)"
  end

  if is_nil(music_box_uri.host) do
    raise "MB_URL is missing hostname (example value: https://example.com)"
  end

  database_path =
    System.get_env("MB_DATABASE_PATH") ||
      raise """
      environment variable MB_DATABASE_PATH is missing.
      For example: /etc/music_box/music_box.db
      """

  transcode_cache_path =
    System.get_env("MB_TRANSCODE_CACHE_PATH") ||
      raise """
      environment variable MB_TRANSCODE_CACHE_PATH is missing.
      For example: /tmp/transcode-cache/
      """

  artwork_path =
    System.get_env("MB_ARTWORK_PATH") ||
      raise """
      environment variable MB_ARTWORK_PATH is missing.
      For example: /tmp/artwork/
      """

  web_enabled? =
    System.get_env("MB_DISABLE_WEB", "false")
    |> String.downcase()
    |> case do
      falsy when falsy in ~w(0 no off disabled false) -> true
      _ -> false
    end

  docs_enabled? =
    System.get_env("MB_DISABLE_DOCS", "false")
    |> String.downcase()
    |> case do
      falsy when falsy in ~w(0 no off disabled false) -> true
      _ -> false
    end

  # Drivers are either "file" (the default) or "s3".
  get_driver = fn name, file_impl, s3_impl ->
    case System.get_env(name, "file") |> String.downcase() do
      "file" -> file_impl
      "s3" -> s3_impl
      other -> raise "environment variable #{name} should be file or s3, got: #{inspect(other)}"
    end
  end

  file_storage_impl =
    get_driver.(
      "MB_STORAGE_DRIVER",
      MusicBox.Storage.File,
      MusicBox.Storage.S3
    )

  transcoder_cache_impl =
    get_driver.(
      "MB_TRANSCODE_CACHE_DRIVER",
      MusicBox.Transcoder.Cache.File,
      MusicBox.Transcoder.Cache.S3
    )

  if file_storage_impl == MusicBox.Storage.S3 do
    bucket =
      System.get_env("MB_STORAGE_S3_BUCKET") ||
        raise """
        environment variable MB_STORAGE_S3_BUCKET is missing.
        For example: my-s3-bucket-name
        """

    region =
      System.get_env("MB_STORAGE_S3_REGION") ||
        raise """
        environment variable MB_STORAGE_S3_REGION is missing.
        For example: us-east-1
        """

    config :music_box, MusicBox.Storage.S3,
      bucket: bucket,
      region: region
  end

  if transcoder_cache_impl == MusicBox.Transcoder.Cache.S3 do
    bucket =
      System.get_env("MB_TRANSCODE_S3_BUCKET") ||
        raise """
        environment variable MB_TRANSCODE_S3_BUCKET is missing.
        For example: my-s3-bucket-name
        """

    region =
      System.get_env("MB_TRANSCODE_S3_REGION") ||
        raise """
        environment variable MB_TRANSCODE_S3_REGION is missing.
        For example: us-east-1
        """

    config :music_box, MusicBox.Transcoder.Cache.S3,
      bucket: bucket,
      region: region
  end

  config :music_box, web_enabled: web_enabled?
  config :music_box, docs_enabled: docs_enabled?

  config :music_box, storage_impl: file_storage_impl

  config :music_box, MusicBox.Transcoder, cache_impl: transcoder_cache_impl

  config :music_box, MusicBox.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("MB_SQLITE_POOL_SIZE") || "1")

  config :music_box, MusicBox.Artwork, artwork_path: Path.absname(artwork_path)

  # In megabytes, 0 for no limit.
  transcode_max_cache_size =
    case String.to_integer(System.get_env("MB_TRANSCODE_CACHE_MAX_SIZE") || "10240") do
      0 -> nil
      megabytes -> megabytes * 1024 * 1024
    end

  config :music_box, MusicBox.Transcoder,
    max_concurrency: String.to_integer(System.get_env("MB_TRANSCODE_MAX_CONCURRENCY") || "3"),
    max_queue_size: String.to_integer(System.get_env("MB_TRANSCODE_QUEUE_SIZE") || "10"),
    cache_path: Path.absname(transcode_cache_path),
    max_cache_size: transcode_max_cache_size

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("MB_SECRET_KEY_BASE") ||
      raise """
      environment variable MB_SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

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
end
