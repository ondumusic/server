defmodule MusicBoxWeb.LibraryController do
  use MusicBoxWeb, :controller

  alias MusicBox.Artists
  alias MusicBox.Albums
  alias MusicBox.Songs

  plug :assign_artist when action in [:artist, :artist_albums]
  plug :assign_album when action in [:album]

  def artists(conn, params) do
    render(conn, :artists, page: Artists.paginate_artists(params))
  end

  def artist(conn, _params) do
    albums = Albums.get_albums_for_artist(conn.assigns.artist)
    render(conn, :artist, artist: conn.assigns.artist, albums: albums)
  end

  def artist_albums(conn, _params) do
    albums = Albums.get_albums_for_artist(conn.assigns.artist)
    render(conn, :albums, albums: albums)
  end

  def albums(conn, params) do
    render(conn, :albums, page: Albums.paginate_albums(params))
  end

  def album(conn, _params) do
    songs = Songs.get_songs_for_album(conn.assigns.album)
    render(conn, :album, album: conn.assigns.album, songs: songs)
  end

  defp assign_artist(conn, _opts) do
    artist_id = Map.get(conn.params, "artist_id", "")
    artist = Artists.get_artist!(artist_id)

    conn
    |> assign(:artist, artist)
  end

  defp assign_album(conn, _opts) do
    album_id = Map.get(conn.params, "album_id", "")
    album = Albums.get_album!(album_id)

    conn
    |> assign(:album, album)
  end
end
