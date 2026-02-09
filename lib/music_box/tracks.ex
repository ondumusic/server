defmodule MusicBox.Tracks do
  @moduledoc false

  import Ecto.Query, warn: false
  alias MusicBox.Repo

  alias MusicBox.Tracks.{IndexForm, Track, Query}

  @spec paginate_tracks(map()) :: Repo.page(Track)
  def paginate_tracks(params) do
    %IndexForm{}
    |> IndexForm.new(params)
    |> Query.paginate_tracks()
    |> Repo.paginate(params)
  end

  @spec get_track!(Ecto.UUID.t()) :: Track.t()
  def get_track!(id), do: Repo.get!(Track, id) |> Repo.preload([:artist, :album, :file])
end
