defmodule MusicBox.Artwork.Fetcher do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__)
    end
  end

  alias MusicBox.Albums.Album
  alias MusicBox.Albums.CoverFile
  require Logger

  @type context :: %{dirs: [String.t()], cover: CoverFile.t() | nil}
  @type result :: %{unprocessed_path: String.t(), source_path: String.t()}
  @type find_error :: :not_found | :failed_to_write | :too_large

  # We'll limit the artwork images in file size because the larger they get the
  # more memory they'll cost to process, and it is unlikely we will ever really
  # hit this limit under normal use.
  @max_size 25 * 1024 * 1024

  @doc "Finds the artwork of an album and saves it with `save_artwork/2`."
  @callback find(album :: Album.t(), context :: context()) ::
              {:ok, result()} | {:error, find_error()}

  @spec max_size() :: pos_integer()
  def max_size, do: @max_size

  @spec save_artwork(Album.t(), binary()) ::
          {:ok, String.t()} | {:error, :failed_to_write | :too_large}
  def save_artwork(album, bytes) when byte_size(bytes) > @max_size do
    Logger.warning("Artwork of album #{album.id} is too large (#{byte_size(bytes)} bytes)")
    {:error, :too_large}
  end

  def save_artwork(album, bytes) do
    path = unprocessed_path(album)
    tmp_path = tmp_path(path)
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
    MusicBox.Config.artwork_path()
    |> Path.join("#{album.id}.source")
  end

  @spec tmp_path(String.t()) :: String.t()
  def tmp_path(path) do
    Path.rootname(path) <> ".#{System.unique_integer([:positive])}.tmp" <> Path.extname(path)
  end
end
