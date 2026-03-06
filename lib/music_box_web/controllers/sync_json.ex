defmodule MusicBoxWeb.SyncJSON do
  use MusicBoxWeb, :json

  alias MusicBoxWeb.LibraryJSON

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
      deletions: [],
      cursor: cursor,
      complete: not incomplete?
    }
  end
end
