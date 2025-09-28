defmodule MusicBox.Artwork.Fetcher.CustomApi do
  @moduledoc false

  use MusicBox.Artwork.Fetcher

  @endpoint Application.compile_env!(:music_box, :custom_artwork_endpoint)

  if is_nil(@endpoint) do
    def find(_album), do: {:error, :skip}
  else
    alias MusicBox.Repo

    def find(album) do
      album = Repo.preload(album, [:artist])

      search_payload = %{
        artist: album.artist.name,
        album: album.name,
        release_year: album.release_year
      }

      case Req.get(@endpoint, params: search_payload) do
        {:ok, %{status: 200, body: bytes}} -> save_artwork(album, bytes)
        _ -> {:error, :not_found}
      end
    end
  end
end
