defmodule MusicBoxWeb.LibraryChannel do
  @moduledoc false

  use Phoenix.Channel

  alias MusicBox.Albums.Album
  alias MusicBox.Artists.Artist
  alias MusicBox.Playlists.Playlist
  alias MusicBox.Playlists.PlaylistItem
  alias MusicBox.Repo
  alias MusicBoxWeb.{LibraryJSON, PlaylistJSON}

  import Ecto.Query

  intercept ["processed"]

  def join("library:sync", _message, socket) do
    {:ok, socket}
  end

  def handle_out("processed", changes, socket) do
    json_changes =
      changes
      |> Enum.map(fn
        {:artists = k, artist_ids} ->
          {k, fetch_artists(artist_ids)}

        {:albums = k, album_ids} ->
          {k, fetch_albums(album_ids)}

        {:playlists = k, playlist_ids} ->
          {k, fetch_playlists(playlist_ids)}

        {:playlist_items, playlist_item_ids} ->
          {:playlistItems, fetch_playlist_items(playlist_item_ids)}
      end)
      |> Map.new()

    push(socket, "processed", json_changes)
    {:noreply, socket}
  end

  defp fetch_artists(ids) do
    from(a in Artist.preloaded(),
      where: a.id in ^ids
    )
    |> Repo.all()
    |> Enum.filter(&(&1.album_count > 0))
    |> Enum.map(&LibraryJSON.artist(%{artist: &1}))
  end

  defp fetch_albums(ids) do
    from(al in Album.preloaded(),
      where: al.id in ^ids
    )
    |> Repo.all()
    |> Enum.map(&LibraryJSON.album(%{album: &1}))
  end

  defp fetch_playlists(ids) do
    from(p in Playlist.preloaded(),
      where: p.id in ^ids
    )
    |> Repo.all()
    |> Enum.map(&PlaylistJSON.playlist(%{playlist: &1}))
  end

  defp fetch_playlist_items(ids) do
    from(p in PlaylistItem.preloaded(),
      where: p.id in ^ids
    )
    |> Repo.all()
    |> Enum.map(&PlaylistJSON.playlist_item(%{playlist_item: &1}))
  end
end
