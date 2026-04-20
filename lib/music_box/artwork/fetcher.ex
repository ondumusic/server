defmodule MusicBox.Artwork.Fetcher do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__)
    end
  end

  alias MusicBox.Albums.Album
  require Logger

  @type find_error :: :skip | :not_found | :retry_later
  @callback find(album :: Album.t()) :: {:ok, String.t()} | {:error, find_error()}

  @spec save_artwork(Album.t(), binary()) :: {:ok, String.t()} | {:error, :failed_to_write}
  def save_artwork(album, bytes) do
    path = artwork_path(album)
    File.mkdir_p!(Path.dirname(path))

    with {:ok, file} <- File.open(path, [:write, :binary, :raw]),
         :ok <- IO.binwrite(file, bytes),
         :ok <- File.close(file),
         {:ok, %{size: size}} when size > 0 <- File.stat(path) do
      {:ok, path}
    else
      {:ok, %{size: 0}} ->
        File.rm(path)
        Logger.error("Failed to write #{path} (reason: empty file)")
        {:error, :failed_to_write}

      {:error, reason} ->
        File.rm(path)
        Logger.error("Failed to write #{path} (reason: #{reason})")
        {:error, :failed_to_write}

      _ ->
        {:error, :failed_to_write}
    end
  end

  def artwork_path(album) do
    MusicBox.Config.artwork_path()
    |> Path.join("#{album.id}.jpg")
  end
end
