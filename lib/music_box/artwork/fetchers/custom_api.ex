defmodule MusicBox.Artwork.Fetcher.CustomApi do
  @moduledoc false

  use MusicBox.Artwork.Fetcher

  alias MusicBox.Repo

  def find(album) do
    endpoint = MusicBox.Config.artwork_custom_api()

    if endpoint do
      album = Repo.preload(album, [:artist])

      search_payload = %{
        artist: album.artist.name,
        album: album.name,
        release_year: album.release_year
      }

      case Req.get(endpoint, params: search_payload) do
        {:ok, %{status: 200, body: bytes}} -> save_artwork(album, bytes)
        _ -> {:error, :not_found}
      end
    else
      {:error, :skip}
    end
  end
end
