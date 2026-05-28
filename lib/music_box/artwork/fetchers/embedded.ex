defmodule MusicBox.Artwork.Fetcher.Embedded do
  @moduledoc false

  use MusicBox.Artwork.Fetcher

  alias MusicBox.Repo
  alias MusicBox.Storage
  alias MusicBox.Tool

  def find(album) do
    album = Repo.preload(album, tracks: [:file])

    album.tracks
    |> Enum.reduce_while(nil, fn track, result ->
      track.file.path
      |> Storage.get_uri()
      |> Tool.extract_artwork()
      |> case do
        {:error, :not_found} -> {:cont, result}
        bytes -> {:halt, bytes}
      end
    end)
    |> case do
      nil -> {:error, :not_found}
      bytes -> save_artwork(album, bytes)
    end
  end
end
