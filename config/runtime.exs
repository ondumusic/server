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
#     PHX_SERVER=true bin/ondu start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :ondu, OnduWeb.Endpoint, server: true
end

config :ondu, Ondu.Repo,
  journal_mode: :wal,
  default_transaction_mode: :immediate,
  temp_store: :memory,
  cache_size: 64_000

if config_env() == :prod do
  ondu_uri =
    System.get_env("ONDU_URL") ||
      raise """
      environment variable ONDU_URL is missing.
      For example: https://music.example.com/
      """

  ondu_uri = URI.parse(ondu_uri)

  if is_nil(ondu_uri.scheme) do
    raise "ONDU_URL is missing scheme (example value: https://example.com)"
  end

  if is_nil(ondu_uri.host) do
    raise "ONDU_URL is missing hostname (example value: https://example.com)"
  end

  database_path =
    System.get_env("ONDU_DATABASE_PATH") ||
      raise """
      environment variable ONDU_DATABASE_PATH is missing.
      For example: /etc/ondu/ondu.db
      """

  transcode_cache_path =
    System.get_env("ONDU_TRANSCODE_CACHE_PATH") ||
      raise """
      environment variable ONDU_TRANSCODE_CACHE_PATH is missing.
      For example: /tmp/transcode-cache/
      """

  artwork_path =
    System.get_env("ONDU_ARTWORK_PATH") ||
      raise """
      environment variable ONDU_ARTWORK_PATH is missing.
      For example: /tmp/artwork/
      """

  web_enabled? =
    System.get_env("ONDU_DISABLE_WEB", "false")
    |> String.downcase()
    |> case do
      falsy when falsy in ~w(0 no off disabled false) -> true
      _ -> false
    end

  docs_enabled? =
    System.get_env("ONDU_DISABLE_DOCS", "false")
    |> String.downcase()
    |> case do
      falsy when falsy in ~w(0 no off disabled false) -> true
      _ -> false
    end

  file_storage_impl =
    case System.get_env("ONDU_STORAGE_DRIVER", "file") |> String.downcase() do
      "file" ->
        Ondu.Storage.File

      "s3" ->
        Ondu.Storage.S3

      other ->
        raise "environment variable ONDU_STORAGE_DRIVER should be file or s3, got: #{inspect(other)}"
    end

  if file_storage_impl == Ondu.Storage.S3 do
    bucket =
      System.get_env("ONDU_STORAGE_S3_BUCKET") ||
        raise """
        environment variable ONDU_STORAGE_S3_BUCKET is missing.
        For example: my-s3-bucket-name
        """

    region =
      System.get_env("ONDU_STORAGE_S3_REGION") ||
        raise """
        environment variable ONDU_STORAGE_S3_REGION is missing.
        For example: us-east-1
        """

    config :ondu, Ondu.Storage.S3,
      bucket: bucket,
      region: region
  end

  config :ondu, web_enabled: web_enabled?
  config :ondu, docs_enabled: docs_enabled?

  config :ondu, storage_impl: file_storage_impl

  config :ondu, Ondu.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("ONDU_SQLITE_POOL_SIZE") || "1")

  config :ondu, Ondu.Artwork, artwork_path: Path.absname(artwork_path)

  # In megabytes, 0 for no limit.
  transcode_max_cache_size =
    case String.to_integer(System.get_env("ONDU_TRANSCODE_CACHE_MAX_SIZE") || "10240") do
      0 -> nil
      megabytes -> megabytes * 1024 * 1024
    end

  config :ondu, Ondu.Transcoder,
    max_concurrency: String.to_integer(System.get_env("ONDU_TRANSCODE_MAX_CONCURRENCY") || "3"),
    max_queue_size: String.to_integer(System.get_env("ONDU_TRANSCODE_QUEUE_SIZE") || "10"),
    cache_path: Path.absname(transcode_cache_path),
    max_cache_size: transcode_max_cache_size

  # The secret key base signs the session and play tokens, nothing is encrypted
  # with it, so losing it only logs everyone out. Unless it's set, one is
  # generated on the first start and stored next to the database, which also
  # means deleting that file (and restarting) is all it takes to rotate it.
  secret_key_path = Path.join(Path.dirname(database_path), ".secret_key_base")

  if is_nil(System.get_env("ONDU_SECRET_KEY_BASE")) and not File.exists?(secret_key_path) do
    # Written to a tmp file first, so a crash can't leave a partial secret behind.
    tmp_path = secret_key_path <> ".tmp"

    File.mkdir_p!(Path.dirname(secret_key_path))
    File.write!(tmp_path, 64 |> :crypto.strong_rand_bytes() |> Base.encode64())
    File.chmod!(tmp_path, 0o600)
    File.rename!(tmp_path, secret_key_path)
  end

  secret_key_base =
    System.get_env("ONDU_SECRET_KEY_BASE") ||
      secret_key_path |> File.read!() |> String.trim()

  if byte_size(secret_key_base) < 64 do
    raise """
    the secret key base should be at least 64 characters.
    Set ONDU_SECRET_KEY_BASE or delete #{secret_key_path} to generate a new one.
    """
  end

  config :ondu, OnduWeb.Endpoint,
    url: [host: ondu_uri.host, port: ondu_uri.port, scheme: ondu_uri.scheme],
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
