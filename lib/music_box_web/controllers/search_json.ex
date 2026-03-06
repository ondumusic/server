defmodule MusicBoxWeb.SearchJSON do
  use MusicBoxWeb, :json

  alias MusicBoxWeb.LibraryJSON

  def result(%{result: result}) do
    %{
      artists:
        Enum.map(
          result.artists.entries,
          &LibraryJSON.artist(%{artist: &1})
        ),
      albums:
        Enum.map(
          result.albums.entries,
          &LibraryJSON.album(%{album: &1, render_tracks: false})
        ),
      tracks:
        Enum.map(
          result.tracks.entries,
          &LibraryJSON.track(%{track: &1, album: &1.album})
        )
    }
  end
end
