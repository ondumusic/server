defmodule MusicBox.Transcoder.Utils do
  @moduledoc false

  alias MusicBox.Files.File
  alias MusicBox.Transcoder

  @spec bitrate_kbps(Transcoder.preset()) :: non_neg_integer()
  def bitrate_kbps(:mobile_aac), do: 160
  def bitrate_kbps(:default_aac), do: 192
  def bitrate_kbps(:mobile), do: 128
  def bitrate_kbps(_default), do: 160

  @spec chunk_size() :: non_neg_integer()
  def chunk_size, do: 1024 * 128

  @spec default_range_size() :: non_neg_integer()
  def default_range_size, do: 1024 * 256

  @spec timestamp() :: non_neg_integer()
  def timestamp, do: DateTime.utc_now() |> DateTime.to_unix()

  @spec estimate_file_size(File.t(), Transcoder.preset()) :: non_neg_integer()
  def estimate_file_size(%File{metadata: %{duration: duration}}, preset)
      when preset in ~w(mobile_aac default_aac)a do
    audio_bytes = bitrate_kbps(preset) * 1000 * duration / 8
    est_overhead = 1.06
    round(audio_bytes * est_overhead)
  end

  def estimate_file_size(%File{metadata: %{duration: duration}}, preset) do
    audio_bytes = bitrate_kbps(preset) * 1000 * duration / 8

    # Estimate the container and opus overhead (6%)
    # this is most likely too much, but that's preferred because if we
    # underestimate the transcode stream might end abruptly depending on client
    est_overhead = 1.06
    round(audio_bytes * est_overhead)
  end

  @spec continue_stream?(File.t(), Transcoder.preset(), non_neg_integer()) :: boolean()
  def continue_stream?(file, preset, chunk_index) do
    meta = Transcoder.get_meta(file, preset)

    if meta do
      continue? = is_nil(meta.failed_at)

      continue? =
        if continue?,
          do: is_nil(meta.completed_at) or chunk_index < meta.chunk_count,
          else: continue?

      continue?
    else
      true
    end
  end

  @spec get_chunk_part(binary(), non_neg_integer(), non_neg_integer()) ::
          {binary(), non_neg_integer()}
  def get_chunk_part(data, offset, size) do
    offset = max(0, offset)
    size_in_chunk = min(byte_size(data) - offset - 1, size - offset)
    chunk_part_data = binary_part(data, offset, size_in_chunk + 1)
    remaining_bytes = max(0, size - byte_size(chunk_part_data))

    {chunk_part_data, remaining_bytes}
  end

  @type range_error :: :no_range | :invalid_range
  @spec parse_range_header([String.t()]) ::
          {:ok, non_neg_integer(), non_neg_integer() | :infinity} | {:error, range_error()}
  def parse_range_header([]), do: {:error, :no_range}
  def parse_range_header(["bytes=0-"]), do: {:ok, 0, :infinity}

  def parse_range_header(["bytes=" <> range]) do
    case String.split(range, "-", parts: 2) do
      [start_str, ""] ->
        case Integer.parse(start_str) do
          {start_byte, ""} when start_byte >= 0 -> {:ok, start_byte, :infinity}
          _ -> {:error, :invalid_range}
        end

      [start_str, end_str] ->
        with {start_byte, ""} when start_byte >= 0 <- Integer.parse(start_str),
             {end_byte, ""} when end_byte >= 0 <- Integer.parse(end_str) do
          {:ok, start_byte, end_byte}
        else
          _ -> {:error, :invalid_range}
        end

      _ ->
        {:error, :invalid_range}
    end
  end

  def parse_range_header(_), do: {:error, :invalid_range}
end
