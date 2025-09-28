defmodule MusicBox.Tracks do
  @moduledoc false

  import Ecto.Query, warn: false
  alias MusicBox.Repo

  alias MusicBox.Tracks.Track

  def get_track!(id), do: Repo.get!(Track, id) |> Repo.preload([:artist, :album, :file])
end
