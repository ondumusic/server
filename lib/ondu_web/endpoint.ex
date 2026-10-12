defmodule OnduWeb.Endpoint do
  @moduledoc false

  use Phoenix.Endpoint, otp_app: :ondu

  socket "/socket", OnduWeb.UserSocket,
    websocket: true,
    longpoll: false,
    auth_token: true

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :ondu,
    gzip: true,
    only: OnduWeb.static_paths()

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :ondu
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint], log: {__MODULE__, :log_level, []}

  plug Plug.Parsers,
    # Artwork can be uploaded (up to 25MB), Plug limits multipart bodies to 8MB
    # by default. Some extra room for the rest of the multipart body.
    parsers: [:urlencoded, {:multipart, length: Ondu.Artwork.max_size() + 1_000_000}, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug OnduWeb.Router

  # For some requests we'll only log them at the debug level because otherwise
  # it's mostly noise. So think about health checks, artwork or audio streams.
  def log_level(%{path_info: [path | _]}) when path in ~w(artwork stream download health),
    do: :debug

  def log_level(%{path_info: ["api", "tracks", _track_id, "transcode"]}), do: :debug
  def log_level(_conn), do: :info
end
