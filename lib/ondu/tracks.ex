defmodule Ondu.Tracks do
  @moduledoc false

  import Ecto.Query, warn: false
  alias Ondu.Repo
  alias Ondu.Tracks.{IndexForm, Query, Track}

  @spec paginate_tracks(map()) :: Repo.page(Track)
  def paginate_tracks(params) do
    %IndexForm{}
    |> IndexForm.new(params)
    |> Query.paginate_tracks()
    |> Repo.paginate(params)
  end

  @spec get_track!(Ecto.UUID.t()) :: Track.t()
  def get_track!(id),
    do: Repo.get!(Track, id) |> Repo.preload([:file, artist: :artwork, album: :artwork])
end
