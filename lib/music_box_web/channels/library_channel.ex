defmodule MusicBoxWeb.LibraryChannel do
  use Phoenix.Channel
  alias MusicBoxWeb.LibraryJSON
  alias MusicBox.Repo
  import Ecto.Query

  intercept ["processed"]

  def join("library:updated", _message, socket) do
    {:ok, socket}
  end

  def handle_out("processed", changes, socket) do
    json_changes =
      changes
      |> Enum.map(fn
        {:artists = k, artist_ids} -> {k, fetch_artists(socket, artist_ids)}
        {:albums = k, album_ids} -> {k, fetch_albums(socket, album_ids)}
      end)
      |> Map.new()

    push(socket, "processed", json_changes)
    {:noreply, socket}
  end

  defp fetch_artists(_socket, ids) do
    from(a in MusicBox.Artists.Artist.preloaded(),
      where: a.id in ^ids
    )
    |> Repo.all()
    |> Enum.map(&LibraryJSON.artist(%{artist: &1}))
  end

  defp fetch_albums(socket, ids) do
    # Right now LibraryJSON.album/track expects a conn object and uses that
    # to get the secret key base and the current_user. This is a quick dirty
    # workaround but need to rethink the whole auth for streams anyway.
    conn = %{
      assigns: socket.assigns,
      secret_key_base: socket.endpoint.config(:secret_key_base)
    }

    from(al in MusicBox.Albums.Album.preloaded(),
      where: al.id in ^ids
    )
    |> Repo.all()
    |> Enum.map(&LibraryJSON.album(%{album: &1, conn: conn}))
  end
end
