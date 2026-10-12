defmodule Ondu.Artwork.Fetcher.Embedded do
  @moduledoc false

  use Ondu.Artwork.Fetcher

  alias Ondu.Repo
  alias Ondu.Storage
  alias Ondu.Tool

  def find(album, _context) do
    album = Repo.preload(album, tracks: [:file])

    album.tracks
    |> Enum.reduce_while(nil, fn track, result ->
      track.file.path
      |> Storage.get_uri()
      |> Tool.extract_artwork()
      |> case do
        {:error, :not_found} -> {:cont, result}
        bytes -> {:halt, {track.file.path, bytes}}
      end
    end)
    |> case do
      nil ->
        {:error, :not_found}

      {track_path, bytes} ->
        with {:ok, path} <- save_artwork(album, bytes, track_path),
             do: {:ok, %{unprocessed_path: path, source_path: track_path}}
    end
  end
end
