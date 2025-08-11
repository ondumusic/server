defmodule MusicBox.Albums do
  import Ecto.Query, warn: false
  alias MusicBox.Repo

  alias MusicBox.Albums.Album
  alias MusicBox.Artists.Artist

  def paginate_albums(params) do
    from(a in Album,
      order_by: [desc_nulls_last: a.release_year, asc: a.name]
    )
    |> Repo.paginate(params)
  end

  def paginate_albums_for_artist(%Artist{id: artist_id}, params) do
    from(a in Album,
      where: a.artist_id == ^artist_id,
      order_by: [desc_nulls_last: a.release_year, asc: a.name],
      preload: [tracks: [:artist]]
    )
    |> Repo.paginate(params, default_limit: 10)
  end

  def get_album!(id) do
    from(a in Album,
      order_by: [asc: a.name],
      where: a.id == ^id,
      preload: [tracks: [:artist]]
    )
    |> Repo.one!()
  end

  def get_album_for_artist!(%Artist{id: artist_id}, id_or_slug) do
    from(a in Album,
      order_by: [asc: a.name],
      where: a.artist_id == ^artist_id,
      where: a.id == ^id_or_slug or a.slug == ^id_or_slug,
      preload: [tracks: [:artist]]
    )
    |> Repo.one!()
  end
end
