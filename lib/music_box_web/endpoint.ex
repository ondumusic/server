defmodule MusicBoxWeb.Endpoint do
  @moduledoc false

  use Phoenix.Endpoint, otp_app: :music_box

  socket "/socket", MusicBoxWeb.UserSocket,
    websocket: true,
    longpoll: false,
    auth_token: true

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :music_box,
    gzip: true,
    only: MusicBoxWeb.static_paths()

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :music_box
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    # Artwork can be uploaded (up to 25MB), Plug limits multipart bodies to 8MB
    # by default. Some extra room for the rest of the multipart body.
    parsers: [:urlencoded, {:multipart, length: MusicBox.Artwork.max_size() + 1_000_000}, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug MusicBoxWeb.Router
end
