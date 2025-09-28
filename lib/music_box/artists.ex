defmodule MusicBox.Artists do
  @moduledoc false

  import Ecto.Query, warn: false
  alias MusicBox.Repo

  alias MusicBox.Albums.Album
  alias MusicBox.Artists.Artist
  alias MusicBox.Tracks.Track

  def paginate_artists(params) do
    album_artists_query =
      from(
        al in Album,
        select: al.artist_id,
        distinct: true
      )

    unlisted_track_artists_query =
      from(t in Track,
        select: t.artist_id,
        where: is_nil(t.album_id),
        distinct: true
      )

    combined_query = union(album_artists_query, ^unlisted_track_artists_query)

    Artist.preloaded()
    |> with_cte("combined", as: ^combined_query)
    |> where(
      [artist: a],
      exists(from(c in "combined", where: c.artist_id == parent_as(:artist).id, select: true))
    )
    |> order_by([artist: a], asc: a.name)
    |> Repo.paginate(params, default_limit: 100)
  end

  def get_artist!(id_or_slug) do
    Artist.preloaded()
    |> where([artist: a], a.id == ^id_or_slug or a.slug == ^id_or_slug)
    |> Repo.one!()
  end
end
