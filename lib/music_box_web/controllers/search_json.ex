defmodule MusicBoxWeb.SearchJSON do
  use MusicBoxWeb, :json

  alias MusicBoxWeb.LibraryJSON

  def results(assigns) do
    %{
      results: json_map(assigns, [:results], :result)
    }
  end

  def result(%{result: result}) do
    %{
      artist: LibraryJSON.artist(%{artist: result.artist}),
      album: LibraryJSON.album(%{album: result.album}),
      track: LibraryJSON.track(%{track: result.track, album: result.album})
    }
  end
end
