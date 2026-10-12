defmodule Ondu.Artwork.Fetcher.CoverFile do
  @moduledoc false

  use Ondu.Artwork.Fetcher

  alias Ondu.Storage
  require Logger

  @max_size Ondu.Artwork.max_size()

  def find(_album, %{cover: nil}), do: {:error, :not_found}

  def find(album, %{cover: %{size: size} = cover}) when size > @max_size do
    Logger.warning("Cover file #{cover.path} of album #{album.id} is too large (#{size} bytes)")
    {:error, :too_large}
  end

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
