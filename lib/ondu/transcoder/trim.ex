defmodule Ondu.Transcoder.Trim do
  @moduledoc """
  How many samples ffmpeg will encode of a source, from its probe.

  Two things need the number. An AAC stream ends with padding up to a whole
  frame, which ffmpeg keeps when decoding, so a transcode of an album track
  would end in a few milliseconds of padding and the next track would start
  late: the count lets the transcode cut the padding off. And the padding of
  the transcode itself carries the stream's final granule position, which is
  this count resampled, so it can be written before the audio is encoded.

  The count is only given when it is exact: a sample count in the container
  (lossless formats, Ogg, MP4 with its edit list, Apple's iTunSMPB tag, an
  MP3 with a LAME header). ffprobe estimates the rest from the bitrate, and
  those are transcoded whole, as before, with nothing promised about their
  end.
  """

  @spec valid_samples(probe :: map()) :: non_neg_integer() | nil
  def valid_samples(probe) do
    format = get_in(probe, ["format", "format_name"]) || ""

    case audio_stream(probe) do
      %{"codec_name" => codec} = stream -> count(codec, format, stream, probe)
      _other -> nil
    end
  end

  # Raw ADTS has no length of its own, ffprobe guesses it from the bitrate.
  defp count("aac", "aac", _stream, _probe), do: nil

  defp count("aac", _format, stream, probe),
    do: from_itunsmpb(tags(probe, stream)) || after_start(stream)

  defp count("mp3", _format, stream, _probe),
    do: if(lame_header?(stream), do: from_stream(stream))

  defp count("opus", _format, stream, _probe), do: without_padding(from_stream(stream), stream)

  defp count(codec, _format, stream, _probe) when codec in ~w(flac alac vorbis),
    do: from_stream(stream)

  defp count("pcm_" <> _, _format, stream, _probe), do: from_stream(stream)
  defp count(_codec, _format, _stream, _probe), do: nil

  @doc "The sample rate of the source's audio."
  @spec sample_rate(probe :: map()) :: pos_integer() | nil
  def sample_rate(probe) do
    case audio_stream(probe) do
      %{"sample_rate" => rate} -> integer(rate)
      _other -> nil
    end
  end

  defp audio_stream(probe) do
    probe
    |> Map.get("streams", [])
    |> Enum.find(&(&1["codec_type"] == "audio"))
  end

  defp tags(probe, stream) do
    Map.merge(stream["tags"] || %{}, get_in(probe, ["format", "tags"]) || %{})
  end

  # "00000000 00000840 000001C8 0000000000B185F8 ...": delay, padding, valid samples.
  defp from_itunsmpb(tags) do
    value =
      Enum.find_value(tags, fn {key, value} -> String.downcase(key) == "itunsmpb" && value end)

    with true <- is_binary(value),
         [_, _delay, _padding, valid | _] <- String.split(String.trim(value), ~r/\s+/),
         {samples, ""} when samples > 0 <- Integer.parse(valid, 16) do
      samples
    else
      _ -> nil
    end
  end

  # An AAC stream's duration counts from its first sample, before the encoder
  # delay that ffprobe reports as its start and ffmpeg skips.
  defp after_start(stream) do
    with samples when is_integer(samples) <- from_stream(stream),
         start when is_integer(start) and start >= 0 and start < samples <-
           integer(stream["start_pts"]) || 0 do
      samples - start
    else
      _ -> nil
    end
  end

  # The stream duration converted from the stream's time base to samples,
  # when that conversion is exact.
  defp from_stream(stream) do
    with duration when is_integer(duration) and duration > 0 <- integer(stream["duration_ts"]),
         rate when is_integer(rate) and rate > 0 <- integer(stream["sample_rate"]),
         {num, den} <- time_base(stream["time_base"]),
         0 <- rem(duration * num * rate, den) do
      div(duration * num * rate, den)
    else
      _ -> nil
    end
  end

  # ffmpeg only knows an MP3's length from its LAME header, which is also
  # where the encoder delay it skips at the start comes from.
  defp lame_header?(stream) do
    case integer(stream["start_pts"]) do
      start when is_integer(start) -> start > 0
      _ -> false
    end
  end

  defp without_padding(nil, _stream), do: nil

  defp without_padding(samples, stream) do
    case integer(stream["initial_padding"]) do
      padding when is_integer(padding) and padding < samples -> samples - padding
      _ -> samples
    end
  end

  defp time_base(value) when is_binary(value) do
    with [num, den] <- String.split(value, "/"),
         {num, ""} <- Integer.parse(num),
         {den, ""} when den > 0 <- Integer.parse(den) do
      {num, den}
    else
      _ -> nil
    end
  end

  defp time_base(_value), do: nil

  defp integer(value) when is_integer(value), do: value

  defp integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp integer(_value), do: nil
end
