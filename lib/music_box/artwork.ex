defmodule MusicBox.Artwork do
  alias MusicBox.Artwork.Fetcher
  alias MusicBox.Albums.Album
  alias MusicBox.Albums
  alias MusicBox.Repo

  def find(%Album{} = album) do
    album = Repo.preload(album, [:artwork])

    case album do
      %{artwork: %{path: path}} when is_binary(path) ->
        {:ok, album}

      _ ->
        case Fetcher.Embedded.find(album) do
          {:ok, path} ->
            update_album(album, path)

          {:error, :not_found} ->
            update_album(album, nil)

          {:error, _error} = error ->
            error
        end
    end
  end

  defp update_album(album, path) do
    Albums.update_artwork(album, %{
      path: path,
      fetcher: :embedded,
      last_fetch_attempt: DateTime.utc_now()
    })
  end
end
