defmodule MusicBox.Storage.S3 do
  @moduledoc false

  @behaviour MusicBox.Storage

  alias MusicBox.Utils
  require Logger

  @presigned_ttl 3_600
  @batch_concurrency 5

  @impl true
  def get_uri(key) do
    {:ok, url} =
      ExAws.S3.presigned_url(
        ExAws.Config.new(:s3, region: region()),
        :get,
        bucket(),
        ensure_prefix(key),
        expires_in: @presigned_ttl
      )

    url
  end

  @impl true
  def validate_origin(prefix_key) do
    prefix_key =
      prefix_key
      |> ensure_prefix()
      |> ensure_trailing_slash()

    bucket()
    |> ExAws.S3.list_objects(prefix: prefix_key, max_keys: 1, region: region())
    |> ExAws.request()
    |> case do
      {:ok, %{body: %{contents: [_ | _]}}} -> :ok
      {:ok, %{body: %{contents: []}}} -> {:error, :enoent}
      {:error, {:http_error, 403, _}} -> {:error, :eacces}
      {:error, {:http_error, 404, _}} -> {:error, :enoent}
      {:error, _reason} -> {:error, :enoent}
    end
  end

  @impl true
  def walk(prefix_key) do
    prefix_key =
      prefix_key
      |> ensure_prefix
      |> ensure_trailing_slash

    bucket()
    |> ExAws.S3.list_objects(prefix: prefix_key)
    |> ExAws.stream!()
    |> Stream.map(fn object ->
      %{
        path: object.key,
        size: String.to_integer(object.size),
        mtime: parse_s3_timestamp(object.last_modified)
      }
    end)
    |> Stream.filter(&Utils.valid_extname?(&1.path))
  end

  @impl true
  def find_missing_files(keys) do
    keys
    |> Task.async_stream(
      fn key ->
        case bucket() |> ExAws.S3.head_object(ensure_prefix(key)) |> ExAws.request() do
          {:ok, _} -> nil
          {:error, _} -> key
        end
      end,
      max_concurrency: @batch_concurrency,
      ordered: false,
      timeout: 15_000
    )
    |> Enum.reduce([], fn
      {:ok, nil}, acc -> acc
      {:ok, key}, acc -> [key | acc]
      {:exit, _reason}, acc -> acc
    end)
  end

  @impl true
  def stream!(key) do
    url = get_uri(key)

    Stream.resource(
      fn ->
        Req.get!(url, into: :self, receive_timeout: 60_000)
      end,
      fn resp ->
        ref = resp.body.ref

        receive do
          {^ref, {:data, chunk}} -> {[chunk], resp}
          {^ref, :done} -> {:halt, resp}
        after
          30_000 -> raise "S3 stream timeout"
        end
      end,
      fn _resp -> :ok end
    )
  end

  @impl true
  def get_bytes(key, start_byte, bytes_to_read) do
    end_byte = start_byte + bytes_to_read - 1
    range = "bytes=#{start_byte}-#{end_byte}"

    bucket()
    |> ExAws.S3.get_object(ensure_prefix(key), range: range)
    |> ExAws.request!()
    |> Map.fetch!(:body)
  end

  # Private
  defp bucket, do: "musicbox-dev"
  defp region, do: "eu-west-1"

  defp ensure_prefix(key), do: String.trim_leading(key, "/")

  defp ensure_trailing_slash(""), do: ""

  defp ensure_trailing_slash(key) do
    if String.ends_with?(key, "/"), do: key, else: key <> "/"
  end

  defp parse_s3_timestamp(timestamp) do
    {:ok, dt, _offset} = DateTime.from_iso8601(timestamp)
    DateTime.truncate(dt, :second)
  end
end
