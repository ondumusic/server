defmodule MusicBox.Artwork.Fetcher.Embedded do
  @moduledoc false

  use MusicBox.Artwork.Fetcher

  alias MusicBox.Repo
  alias MusicBox.Tool

  def find(album) do
    album = Repo.preload(album, tracks: [:file])

    album.tracks
    |> Enum.reduce_while(nil, fn track, result ->
      case Tool.extract_artwork(track.file.path) do
        nil -> {:cont, result}
        bytes -> {:halt, bytes}
      end
    end)
    |> case do
      nil -> {:error, :not_found}
      bytes -> save_artwork(album, bytes)
    end
  end
end
