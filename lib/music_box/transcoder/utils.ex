defmodule MusicBox.Transcoder.Utils do
  alias MusicBox.Transcoder
  alias MusicBox.Files.File

  def bitrate_kbps, do: 256
  def chunk_size, do: 1024 * 1024

  def estimate_opus_size(%File{metadata: %{duration: duration}}) do
    audio_bytes = bitrate_kbps() * 1000 * duration / 8

    # Estimate the container and opus overhead (just add a %)
    webm_container_overhead = audio_bytes * 0.015
    opus_header_overhead = audio_bytes * 0.005

    # Return rounded number
    round(audio_bytes + webm_container_overhead + opus_header_overhead)
  end

  def continue_stream?(file, chunk_index) do
    meta = Transcoder.get_meta(file)

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

  def get_chunk_part(data, offset, size) do
    offset = max(0, offset)
    size_in_chunk = min(byte_size(data) - offset - 1, size - offset)
    chunk_part_data = binary_part(data, offset, size_in_chunk + 1)
    remaining_bytes = max(0, size - byte_size(chunk_part_data))

    {chunk_part_data, remaining_bytes}
  end

  def parse_range_header([]), do: :no_range

  def parse_range_header(["bytes=" <> range]) do
    case String.split(range, "-", parts: 2) do
      [start_str, end_str] ->
        with {start_byte, ""} when start_byte >= 0 <- Integer.parse(start_str),
             {end_byte, ""} when end_byte >= 0 <- Integer.parse(end_str) do
          # end_byte <- parse_end_byte(end_str, start_byte) do
          {:ok, start_byte, end_byte}
        else
          _ -> {:error, :invalid_range}
        end

      _ ->
        {:error, :invalid_range}
    end
  end

  def parse_range_header(_), do: :invalid_range
end
