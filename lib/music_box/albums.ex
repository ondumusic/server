defmodule MusicBox.Albums do
  import Ecto.Query, warn: false
  alias MusicBox.Repo

  alias MusicBox.Albums.Album
  alias MusicBox.Artists.Artist

  def paginate_albums(params) do
    Album.preloaded()
    |> order_by([album: al, artist: a],
      asc: a.name,
      desc_nulls_last: al.release_year,
      asc: al.name
    )
    |> Repo.paginate(params)
  end

  def paginate_albums_for_artist(%Artist{id: artist_id}, params) do
    Album.preloaded()
    |> where([album: al], al.artist_id == ^artist_id)
    |> order_by([album: al], desc_nulls_last: al.release_year, asc: al.name)
    |> Repo.paginate(params)
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
