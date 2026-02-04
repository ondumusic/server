import Config

config :music_box, :env, :test

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :music_box, MusicBox.Repo,
  database: Path.expand("../db/music_box_test.db", __DIR__),
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :music_box, MusicBoxWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "PAou9f9ymlMyqoMzzB0BMe8z+p2REuG+O0LipguNMIsN0h8KbrQ7UAdQHpquTYNZ",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :music_box, probe_tool: MusicBox.Tool.ProbeMock
