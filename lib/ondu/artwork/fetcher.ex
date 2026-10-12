defmodule Ondu.Artwork.Fetcher do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__)
    end
  end

  alias Ondu.Albums.Album
  alias Ondu.Albums.CoverFile
  require Logger

  @type context :: %{dirs: [String.t()], cover: CoverFile.t() | nil}
  @type result :: %{unprocessed_path: String.t(), source_path: String.t()}
  @type find_error :: :not_found | :failed_to_write | :too_large

  @max_size Ondu.Artwork.max_size()

  @doc "Finds the artwork of an album and saves it with `save_artwork/2`."
  @callback find(album :: Album.t(), context :: context()) ::
              {:ok, result()} | {:error, find_error()}

  # The source path is the music or cover file the artwork was read from.
  @spec save_artwork(Album.t(), binary(), String.t()) ::
          {:ok, String.t()} | {:error, :failed_to_write | :too_large}
  def save_artwork(_album, bytes, source_path) when byte_size(bytes) > @max_size do
    Logger.warning("Artwork in #{source_path} is too large (#{byte_size(bytes)} bytes)")
    {:error, :too_large}
  end

  def save_artwork(album, bytes, _source_path) do
    path = unprocessed_path(album)
    tmp_path = Ondu.Artwork.tmp_path(path)
    File.mkdir_p!(Path.dirname(path))

    with {:ok, file} <- File.open(tmp_path, [:write, :binary, :raw]),
         :ok <- IO.binwrite(file, bytes),
         :ok <- File.close(file),
         {:ok, %{size: size}} when size > 0 <- File.stat(tmp_path),
         :ok <- File.rename(tmp_path, path) do
      {:ok, path}
    else
      {:ok, %{size: 0}} ->
        File.rm(tmp_path)
        Logger.error("Failed to write #{path} (reason: empty file)")
        {:error, :failed_to_write}

      {:error, reason} ->
        File.rm(tmp_path)
        Logger.error("Failed to write #{path} (reason: #{reason})")
        {:error, :failed_to_write}
    end
  end

  # The unprocessed artwork, removed again once it has been resized.
  @spec unprocessed_path(Album.t()) :: String.t()
  def unprocessed_path(album) do
    Ondu.Config.artwork_path()
    |> Path.join("#{album.id}.source")
  end
end
