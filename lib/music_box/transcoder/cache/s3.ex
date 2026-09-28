defmodule MusicBox.Transcoder.Cache.S3 do
  @moduledoc false

  @behaviour MusicBox.Transcoder.Cache

  alias MusicBox.Transcoder.{Preset, Result, Utils}

  @impl true
  def get_meta(file_id, preset) do
    key = cache_file_key(file_id, preset)

    config(:bucket)
    |> ExAws.S3.list_objects_v2(prefix: key)
    |> ExAws.request(region: config(:region))
    |> case do
      {:ok, %{body: %{contents: []}}} ->
        {:error, :not_found}

      {:ok, %{body: %{contents: [object | _]}}} ->
        size = String.to_integer(object.size)

        {:ok,
         %Result{
           completed_at: parse_s3_timestamp(object.last_modified),
           file_size: size,
           chunk_count: ceil(size / Utils.chunk_size()),
           persisted: true
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def persist(file_id, preset, callback) do
    key = cache_file_key(file_id, preset)

    config(:bucket)
    |> ExAws.S3.initiate_multipart_upload(key, region: config(:region))
    |> ExAws.request()
    |> case do
      {:ok, upload} -> do_persist(upload, key, callback)
      _ -> {:error, :failed_to_initialize_multipart_upload}
    end
  end

  @dialyzer {:no_return, do_persist: 3}
  defp do_persist(upload, key, callback) do
    upload_id = upload.body.upload_id

    parts =
      callback.()
      |> Stream.chunk_every(100)
      |> Stream.map(fn chunks -> IO.iodata_to_binary(chunks) end)
      |> Stream.with_index(1)
      |> Enum.map(fn {body, part_number} ->
        {:ok, resp} =
          config(:bucket)
          |> ExAws.S3.upload_part(key, upload_id, part_number, body)
          |> ExAws.request(region: config(:region))

        etag = Map.new(resp.headers) |> Map.get("etag")
        {part_number, etag}
      end)

    config(:bucket)
    |> ExAws.S3.complete_multipart_upload(key, upload_id, parts)
    |> ExAws.request(region: config(:region))
    |> case do
      {:ok, _} -> :ok
      {:error, _} = err -> err
    end
  end

  @impl true
  def get_bytes(file_id, preset, start_byte, bytes_to_read) do
    key = cache_file_key(file_id, preset)
    end_byte = start_byte + bytes_to_read - 1
    range = "bytes=#{start_byte}-#{end_byte}"

    config(:bucket)
    |> ExAws.S3.get_object(ensure_prefix(key), range: range)
    |> ExAws.request!(region: config(:region))
    |> Map.fetch!(:body)
  end

  @impl true
  def delete(file_id, preset) do
    config(:bucket)
    |> ExAws.S3.delete_object(cache_file_key(file_id, preset))
    |> ExAws.request(region: config(:region))
    |> case do
      {:ok, _response} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp config(key),
    do: Application.get_env(:music_box, __MODULE__) |> Keyword.get(key)

  @spec cache_file_key(file_id :: String.t(), preset :: Preset.t()) :: String.t()
  def cache_file_key(file_id, %Preset{} = preset) do
    filename = "#{file_id}-#{preset.id}.#{preset.ext}"

    MusicBox.Config.transcode_cache_path()
    |> Path.join(filename)
    |> ensure_prefix()
  end

  defp ensure_prefix(key), do: String.trim_leading(key, "/")

  defp parse_s3_timestamp(timestamp) do
    {:ok, dt, _offset} = DateTime.from_iso8601(timestamp)
    DateTime.truncate(dt, :second)
  end
end
