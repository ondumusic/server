defmodule MusicBox.Repo do
  use Ecto.Repo,
    otp_app: :music_box,
    adapter: Ecto.Adapters.SQLite3
end
