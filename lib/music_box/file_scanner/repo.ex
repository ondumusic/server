defmodule MusicBox.FileScanner.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :music_box,
    adapter: Ecto.Adapters.SQLite3
end
