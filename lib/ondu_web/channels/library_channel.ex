defmodule OnduWeb.LibraryChannel do
  @moduledoc false

  use Phoenix.Channel

  alias Ondu.Albums.Album
  alias Ondu.Artists.Artist
  alias Ondu.Playlists.Playlist
  alias Ondu.Playlists.PlaylistItem
  alias Ondu.Repo
  alias Ondu.Sessions
  alias OnduWeb.{LibraryJSON, NoticeJSON, PlaylistJSON}

  import Ecto.Query

  intercept ["processed", "deleted", "completed", "notices"]

  def join("library:sync", _message, socket) do
    {:ok, socket}
  end

  # Sessions can be logged out while connected (e.g. by changing the password),
  # so check the session before every push. Disconnecting makes the client
  # reconnect with its current session token, if it has one.
  def handle_out(event, payload, socket) do
    if Sessions.get_user_by_session_token(socket.assigns.session_token) do
      push_event(event, payload, socket)
    else
      OnduWeb.Endpoint.broadcast(socket.id, "disconnect", %{})
      {:noreply, socket}
    end
  end

  defp push_event("notices", _payload, socket) do
    notices = Ondu.Notices.active()
    push(socket, "notices", NoticeJSON.notices(%{notices: notices}))
    {:noreply, socket}
  end

  defp push_event("processed", changes, socket) do
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

  defp push_event(event, payload, socket) do
    push(socket, event, payload)
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
