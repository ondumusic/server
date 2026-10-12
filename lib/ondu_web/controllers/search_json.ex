defmodule OnduWeb.SearchJSON do
  use OnduWeb, :json

  alias OnduWeb.LibraryJSON

  def result(%{result: result}) do
    %{
      artists:
        Enum.map(
          result.artists,
          &LibraryJSON.artist(%{artist: &1})
        ),
      albums:
        Enum.map(
          result.albums,
          &LibraryJSON.album(%{album: &1, render_tracks: false})
        ),
      tracks:
        Enum.map(
          result.tracks,
          &LibraryJSON.track(%{track: &1, album: &1.album})
        )
    }
  end
end
