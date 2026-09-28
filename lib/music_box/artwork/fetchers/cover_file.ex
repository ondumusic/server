defmodule MusicBox.Artwork.Fetcher.CoverFile do
  @moduledoc false

  use MusicBox.Artwork.Fetcher

  alias MusicBox.Storage
  require Logger

  def find(_album, %{cover: nil}), do: {:error, :not_found}

  def find(album, %{cover: cover}) do
    bytes = cover.path |> Storage.stream!() |> Enum.join()

    with {:ok, path} <- save_artwork(album, bytes),
         do: {:ok, %{unprocessed_path: path, source_path: cover.path}}
  rescue
    error ->
      Logger.warning("Failed to read cover file for album #{album.id}: #{inspect(error)}")
      {:error, :not_found}
  end
end
