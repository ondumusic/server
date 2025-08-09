defmodule MusicBoxWeb.LibraryController do
  use MusicBoxWeb, :controller

  alias MusicBox.Artists
  alias MusicBox.Albums
  alias MusicBox.Songs

  plug :assign_album_artist when action in [:album_artist, :artist_albums]
  plug :assign_album when action in [:album]

  def album_artists(conn, params) do
    render(conn, :album_artists, page: Artists.paginate_album_artists(params))
  end

  def album_artist(conn, _params) do
    render(conn, :album_artist, artist: conn.assigns.album_artist)
  end

  def artist_albums(conn, params) do
    page = Albums.paginate_albums_for_artist(conn.assigns.album_artist, params)
    render(conn, :albums, page: page)
  end

  def albums(conn, params) do
    render(conn, :albums, page: Albums.paginate_albums(params))
  end

  def album(conn, _params) do
    songs = Songs.get_songs_for_album(conn.assigns.album)
    render(conn, :album, album: conn.assigns.album, songs: songs)
  end

  defp assign_album_artist(conn, _opts) do
    album_artist_id = Map.get(conn.params, "album_artist_id", "")
    album_artist = Artists.get_album_artist!(album_artist_id)

    conn
    |> assign(:album_artist, album_artist)
  end

  defp assign_album(conn, _opts) do
    album_id = Map.get(conn.params, "album_id", "")
    album = Albums.get_album!(album_id)

    conn
    |> assign(:album, album)
  end
end
