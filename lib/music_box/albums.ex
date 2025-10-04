defmodule MusicBox.Albums do
  @moduledoc false

  import Ecto.Query, warn: false
  alias MusicBox.Repo

  alias MusicBox.Albums.{Album, Artwork}
  alias MusicBox.Artists.Artist

  @spec paginate_albums(map()) :: Repo.page(Album)
  def paginate_albums(params) do
    Album.preloaded()
    |> order_by([album: al, artist: a],
      asc: a.name,
      desc_nulls_last: al.release_year,
      asc: al.name
    )
    |> Repo.paginate(params)
  end

  @spec paginate_albums_for_artist(Artist.t(), map()) :: Repo.page(Album)
  def paginate_albums_for_artist(%Artist{id: artist_id}, params) do
    Album.preloaded()
    |> where([album: al], al.artist_id == ^artist_id)
    |> order_by([album: al], desc_nulls_last: al.release_year, asc: al.name)
    |> Repo.paginate(params)
  end

  @spec get_album!(Ecto.UUID.t()) :: Album.t()
  def get_album!(id) do
    Album.preloaded()
    |> where([album: al], al.id == ^id)
    |> Repo.one!()
  end

  @spec get_album_for_artist!(Artist.t(), String.t()) :: Album.t()
  def get_album_for_artist!(%Artist{id: artist_id}, id_or_slug) do
    Album.preloaded()
    |> where([album: al], al.artist_id == ^artist_id)
    |> where([album: al], al.id == ^id_or_slug or al.slug == ^id_or_slug)
    |> Repo.one!()
  end

  @spec update_artwork(Album.t(), map()) :: Repo.result(Artwork.t())
  def update_artwork(%Album{id: album_id}, attrs) do
    %Artwork{
      album_id: album_id
    }
    |> Artwork.changeset(attrs)
    |> Repo.insert(on_conflict: :replace_all)
  end
end
