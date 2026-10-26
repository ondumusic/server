defmodule Ondu.Transcoder.Utils do
  @moduledoc false

  alias Ondu.Files.File
  alias Ondu.Transcoder
  alias Ondu.Transcoder.Preset

  @spec chunk_size() :: non_neg_integer()
  def chunk_size, do: 1024 * 128

  @spec timestamp() :: non_neg_integer()
  def timestamp, do: DateTime.utc_now() |> DateTime.to_unix()

  @doc """
  The size of a transcode: of the completed transcode, else the size it will
  have, which is known before it even started.
  """
  @spec known_file_size(File.t(), Preset.t()) :: non_neg_integer()
  def known_file_size(file, preset) do
    case Transcoder.get_meta(file, preset) do
      %{file_size: size} when is_integer(size) and size > 0 -> size
      _ -> Preset.predicted_size(file, preset)
    end
  end

  @spec calculate_timeout(File.t()) :: non_neg_integer()
  def calculate_timeout(%File{metadata: %{duration: duration}}) do
    # use duration and add some overhead and minimal math to try and
    # create a timeout value for fffmpeg processes.
    round(max(15_000, (duration * 0.1 + 10.0) * 1_000))
  end

  @spec continue_stream?(File.t(), Preset.t(), non_neg_integer()) :: boolean()
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

  @doc """
  The part of a chunk that falls within a byte range of the whole transcode,
  both ends of the range are inclusive.
  """
  @spec slice_chunk(binary(), non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          binary()
  def slice_chunk(data, chunk_index, start_byte, end_byte) do
    chunk_start = chunk_index * chunk_size()
    from = max(start_byte, chunk_start) - chunk_start
    to = min(end_byte, chunk_start + byte_size(data) - 1) - chunk_start

    if to < from, do: <<>>, else: binary_part(data, from, to - from + 1)
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

  # Temporary files are kept next to the cache, so they can be moved into it and
  # leftovers (e.g. after a crash) can be cleaned up.
  @spec tmp_dir() :: String.t()
  def tmp_dir, do: Path.join(Ondu.Config.transcode_cache_path(), "tmp")
end
