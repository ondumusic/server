defmodule MusicBoxWeb.SyncJSON do
  use MusicBoxWeb, :json

  alias MusicBoxWeb.LibraryJSON
  alias MusicBoxWeb.PlaylistJSON

  def result(%{result: result, cursor: cursor}) do
    incomplete? =
      Enum.any?(result, fn {_k, v} ->
        v.has_more?
      end)

    %{
      artists: Enum.map(result.artists.entries, &LibraryJSON.artist(%{artist: &1})),
      albums:
        Enum.map(result.albums.entries, &LibraryJSON.album(%{album: &1, render_tracks: false})),
      tracks:
        Enum.map(
          result.tracks.entries,
          &LibraryJSON.track(%{track: &1, render_album: false, render_artist: false})
        ),
      deletions: Enum.map(result.deletions.entries, &deletion(%{entity: &1})),
      playlists: Enum.map(result.playlists.entries, &PlaylistJSON.playlist(%{playlist: &1})),
      playlistItems:
        Enum.map(result.playlist_items.entries, &PlaylistJSON.playlist_item(%{playlist_item: &1})),
      cursor: cursor,
      complete: not incomplete?
    }
  end

  defp deletion(%{entity: entity}) do
    %{
      "entityType" => entity.entity_type,
      "entityId" => entity.entity_id
    }
  end
end
