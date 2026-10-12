import Config

config :ondu, :env, :test

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :ondu, Ondu.Repo,
  database: Path.expand("../db/ondu_test.db", __DIR__),
  pool_size: 1,
  pool: Ecto.Adapters.SQL.Sandbox,
  busy_timeout: 1_000,
  queue_target: 5_000

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ondu, OnduWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "PAou9f9ymlMyqoMzzB0BMe8z+p2REuG+O0LipguNMIsN0h8KbrQ7UAdQHpquTYNZ",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :ondu,
  transcode_tool: Ondu.Tool.TranscodeMock,
  probe_tool: Ondu.Tool.ProbeMock,
  extract_artwork_tool: Ondu.Tool.ExtractArtworkMock,
  loudness_tool: Ondu.Tool.LoudnessMock

config :ondu,
  settings_cache: false

config :ondu, Ondu.Artwork, artwork_path: Path.absname("./tmp/test/artwork")

config :ondu, Ondu.Transcoder,
  max_concurrency: 3,
  max_queue_size: 6,
  cache_path: Path.absname("./tmp/test/transcode")
