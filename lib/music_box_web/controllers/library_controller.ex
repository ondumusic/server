defmodule MusicBoxWeb.LibraryController do
  use MusicBoxWeb, :controller

  alias MusicBox.Artists
  alias MusicBox.Albums

  plug :assign_artist when action in [:artist, :artist_albums, :artist_album]
  plug :assign_album when action in [:album, :artist_album]

  def artists(conn, params) do
    render(conn, :artists, page: Artists.paginate_artists(params))
  end

  def artist(conn, _params) do
    render(conn, :artist, artist: conn.assigns.artist)
  end

  def artist_albums(conn, params) do
    page = Albums.paginate_albums_for_artist(conn.assigns.artist, params)
    render(conn, :albums, page: page)
  end

  def albums(conn, params) do
    render(conn, :albums, page: Albums.paginate_albums(params))
  end

  def album(conn, _params) do
    render(conn, :album, album: conn.assigns.album)
  end

  def artist_album(conn, _params) do
    render(conn, :album, album: conn.assigns.album)
  end

  defp assign_artist(conn, _opts) do
    artist_id = Map.get(conn.params, "artist_id", "")
    artist = Artists.get_artist!(artist_id)

    conn
    |> assign(:artist, artist)
  end

  defp assign_album(conn, _opts) do
    album_id = Map.get(conn.params, "album_id", "")

    album =
      if artist = conn.assigns[:artist],
        do: Albums.get_album_for_artist!(artist, album_id),
        else: Albums.get_album!(album_id)

    conn
    |> assign(:album, album)
  end
end
