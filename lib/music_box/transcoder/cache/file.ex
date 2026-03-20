defmodule MusicBox.Transcoder.Cache.File do
  @moduledoc false

  @behaviour MusicBox.Transcoder.Cache

  alias MusicBox.Transcoder.{Preset, Result, Utils}

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

  @impl true
  def persist(file_id, preset, callback) do
    path = cache_file_path(file_id, preset)
    File.mkdir_p!(Path.dirname(path))

    case File.open(path, [:write, :binary, :exclusive]) do
      {:ok, file} ->
        callback.()
        |> Enum.each(fn chunk ->
          :ok = IO.binwrite(file, chunk)
        end)

        File.close(file)

      {:error, :eexist} ->
        {:error, :already_exists}

      _ ->
        {:error, :failed_to_persist}
    end
  end

  @impl true
  def get_bytes(file_id, preset, start_byte, bytes_to_read) do
    path = cache_file_path(file_id, preset)

    case File.open(path, [:binary, :read]) do
      {:ok, file} ->
        :file.position(file, start_byte)
        chunk_data = IO.binread(file, bytes_to_read)
        File.close(file)
        chunk_data

      _ ->
        nil
    end
  end

  def cache_file_path(file_id, %Preset{} = preset) do
    filename = "#{file_id}-#{preset.id}.#{preset.ext}"
    Path.join(MusicBox.Config.transcode_cache_path(), filename)
  end
end
