defmodule MusicBox.Artwork.Fetcher do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__)
    end
  end

  alias MusicBox.Albums.Album

  @type find_error :: :skip | :not_found | :retry_later
  @callback find(album :: Album.t()) :: {:ok, String.t()} | {:error, find_error()}

  @spec save_artwork(Album.t(), binary()) :: {:ok, String.t()} | {:error, :failed_to_write}
  def save_artwork(album, bytes) do
    path = artwork_path(album)
    File.mkdir_p!(Path.dirname(path))

    case File.open(path, [:write, :binary]) do
      {:ok, file} ->
        IO.binwrite(file, bytes)
        File.close(file)
        {:ok, path}

      _error ->
        {:error, :failed_to_write}
    end
  end

  def artwork_path(album) do
    MusicBox.Config.artwork_path()
    |> Path.join("#{album.id}.jpg")
  end
end
