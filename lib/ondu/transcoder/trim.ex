defmodule Ondu.Transcoder.Trim do
  @moduledoc """
  How many samples of an AAC source are music, from its probe.

  An AAC stream starts with the encoder delay and ends with padding up to a whole
  frame. ffmpeg drops the delay when decoding but keeps the padding, so a
  transcode of an album track would end in a few milliseconds of padding and the
  next track would start late: an audible click where the album is gapless. The
  valid sample count lets the transcode cut the padding off.

  Apple encoders say so in the `iTunSMPB` tag. Other encoders (ffmpeg among them)
  write an edit list, which ffprobe already applies to the stream duration.
  Without either the whole stream counts, as before. MP3 and the lossless and
  Ogg formats need nothing: ffmpeg trims those itself.
  """

  @spec valid_samples(probe :: map()) :: non_neg_integer() | nil
  def valid_samples(probe) do
    case audio_stream(probe) do
      %{"codec_name" => "aac"} = stream ->
        from_itunsmpb(tags(probe, stream)) || from_stream(stream)

      _other ->
        nil
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

  defp from_stream(stream) do
    with duration when is_integer(duration) <- integer(stream["duration_ts"]),
         start when is_integer(start) and start >= 0 and start < duration <-
           integer(stream["start_pts"]) || 0 do
      duration - start
    else
      _ -> nil
    end
  end

  defp integer(value) when is_integer(value), do: value

  defp integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp integer(_value), do: nil
end
