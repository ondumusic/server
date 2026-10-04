defmodule MusicBox.Transcoder.Cache do
  @moduledoc """
  This module handles the transcoder cache. Completed transcodes are stored in
  the transcode cache path following this naming convention:

      `{file_id}-{preset_id}.{ext}`

  The cache can be limited in total filesize allowed with the cache max size
  setting. The code responsible for cleaning up expired cache files lives in
  the `MusicBox.Transcoder.CacheCleanup` module.
  """

  alias MusicBox.Storage
  alias MusicBox.Transcoder.{Preset, Result, Utils}

  @type entry :: %{
          path: String.t(),
          file_id: String.t(),
          preset_id: String.t(),
          size: non_neg_integer(),
          completed_at: DateTime.t()
        }

  @doc "Returns transcoding metadata for a given file/preset."
  @spec get_meta(file_id :: String.t(), preset :: Preset.t()) ::
          {:ok, Result.t()} | {:error, :not_found}
  def get_meta(file_id, preset) do
    case File.stat(cache_file_path(file_id, preset), time: :posix) do
      {:ok, stat} ->
        {:ok,
         %Result{
           completed_at: DateTime.from_unix!(stat.mtime),
           file_size: stat.size,
           chunk_count: ceil(stat.size / Utils.chunk_size()),
           persisted: true
         }}

      {:error, _reason} ->
        {:error, :not_found}
    end
  end

  @doc """
  Stores the transcode for a file/preset, from the chunks returned by callback.

  It is written to a temporary file first, so an incomplete file (e.g. when the
  disk is full or the server stopped) is never mistaken for a completed
  transcode.
  """
  @spec persist(file_id :: String.t(), preset :: Preset.t(), callback :: (-> Enumerable.t())) ::
          :ok | {:error, :already_exists | :failed_to_persist}
  def persist(file_id, preset, callback) do
    path = cache_file_path(file_id, preset)

    tmp_path =
      Path.join(Utils.tmp_dir(), "#{Path.basename(path)}.#{System.unique_integer([:positive])}")

    with false <- File.exists?(path),
         :ok <- File.mkdir_p(Utils.tmp_dir()),
         :ok <- write_chunks(tmp_path, callback.()),
         :ok <- File.rename(tmp_path, path) do
      :ok
    else
      true ->
        {:error, :already_exists}

      _error ->
        File.rm(tmp_path)
        {:error, :failed_to_persist}
    end
  end

  defp write_chunks(path, chunks) do
    File.open!(path, [:write, :binary], fn file -> Enum.each(chunks, &IO.binwrite(file, &1)) end)
  rescue
    # e.g. when the disk is full
    error in [File.Error, ErlangError] -> {:error, error}
  end

  @doc "Returns a specific range of bytes from a cached transcode."
  @spec get_bytes(
          file_id :: String.t(),
          preset :: Preset.t(),
          start_byte :: non_neg_integer(),
          bytes_to_read :: non_neg_integer()
        ) :: iodata() | nil
  def get_bytes(file_id, preset, start_byte, bytes_to_read) do
    path = cache_file_path(file_id, preset)
    Storage.File.get_bytes(path, start_byte, bytes_to_read)
  end

  @doc """
  Lists all cached transcodes, files that are not named like a cached transcode
  are skipped.
  """
  @spec entries() :: [entry()]
  def entries do
    cache_path = MusicBox.Config.transcode_cache_path()

    case File.ls(cache_path) do
      {:ok, names} -> Enum.flat_map(names, &entry(cache_path, &1))
      {:error, _reason} -> []
    end
  end

  defp entry(cache_path, name) do
    path = Path.join(cache_path, name)

    with {:ok, file_id, preset_id} <- parse_filename(name),
         {:ok, %File.Stat{type: :regular} = stat} <- File.stat(path, time: :posix) do
      [
        %{
          path: path,
          file_id: file_id,
          preset_id: preset_id,
          size: stat.size,
          completed_at: DateTime.from_unix!(stat.mtime)
        }
      ]
    else
      _other -> []
    end
  end

  @doc "Deletes the given cached transcodes."
  @spec delete_entries([entry()]) :: :ok
  def delete_entries(entries), do: Enum.each(entries, &File.rm(&1.path))

  @doc "Deletes the cached transcode for a given file/preset, if there is one."
  @spec delete(file_id :: String.t(), preset :: Preset.t()) :: :ok | {:error, File.posix()}
  def delete(file_id, preset) do
    case File.rm(cache_file_path(file_id, preset)) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Parses a cached file name (`{file_id}-{preset_id}.{ext}`) into the file id and
  preset id.
  """
  @spec parse_filename(String.t()) :: {:ok, String.t(), String.t()} | :error
  def parse_filename(filename) do
    case Regex.run(~r/\A([0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})-(\w+)\.\w+\z/, filename) do
      [_match, file_id, preset_id] -> {:ok, file_id, preset_id}
      nil -> :error
    end
  end

  @spec cache_file_path(String.t(), Preset.t()) :: String.t()
  def cache_file_path(file_id, %Preset{} = preset) do
    filename = "#{file_id}-#{preset.id}.#{preset.ext}"
    Path.join(MusicBox.Config.transcode_cache_path(), filename)
  end
end
