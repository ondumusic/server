defmodule MusicBox.Transcoder.Cache.File do
  @moduledoc false

  @behaviour MusicBox.Transcoder.Cache

  alias MusicBox.Storage
  alias MusicBox.Transcoder.{Cache, Preset, Result, Utils}

  @impl true
  def get_meta(file_id, preset) do
    path = cache_file_path(file_id, preset)

    if File.exists?(path) do
      stat = File.stat!(path, time: :posix)

      {:ok,
       %Result{
         completed_at: DateTime.from_unix!(stat.mtime),
         file_size: stat.size,
         chunk_count: ceil(stat.size / Utils.chunk_size()),
         persisted: true
       }}
    else
      {:error, :not_found}
    end
  end

  # Written to a temporary file first, so an incomplete file (e.g. when the disk
  # is full or the server stopped) is never mistaken for a completed transcode.
  @impl true
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

  @impl true
  def get_bytes(file_id, preset, start_byte, bytes_to_read) do
    path = cache_file_path(file_id, preset)
    Storage.File.get_bytes(path, start_byte, bytes_to_read)
  end

  @impl true
  def entries do
    cache_path = MusicBox.Config.transcode_cache_path()

    case File.ls(cache_path) do
      {:ok, names} ->
        Enum.flat_map(names, &entry(cache_path, &1))

      {:error, _reason} ->
        []
    end
  end

  defp entry(cache_path, name) do
    path = Path.join(cache_path, name)

    with {:ok, file_id, preset_id} <- Cache.parse_filename(name),
         {:ok, %File.Stat{type: :regular} = stat} <- File.stat(path, time: :posix) do
      [
        %{
          key: path,
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

  @impl true
  def delete_entries(entries) do
    Enum.each(entries, &File.rm(&1.key))
  end

  @impl true
  def delete(file_id, preset) do
    case File.rm(cache_file_path(file_id, preset)) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def cache_file_path(file_id, %Preset{} = preset) do
    filename = "#{file_id}-#{preset.id}.#{preset.ext}"
    Path.join(MusicBox.Config.transcode_cache_path(), filename)
  end
end
