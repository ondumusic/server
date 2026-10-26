defmodule Ondu.Transcoder.TrimTest do
  use ExUnit.Case, async: true

  alias Ondu.Transcoder.Trim

  defp probe(stream, format_tags \\ %{}) do
    %{
      "streams" => [Map.merge(%{"codec_type" => "audio", "codec_name" => "aac"}, stream)],
      "format" => %{"tags" => format_tags}
    }
  end

  test "reads the valid sample count from iTunSMPB" do
    smpb = " 00000000 00000840 000001C8 0000000000B185F8 00000000 00000000 00000000 00000000"

    assert Trim.valid_samples(probe(%{"duration_ts" => 11_636_736}, %{"iTunSMPB" => smpb})) ==
             11_634_168

    assert Trim.valid_samples(probe(%{"tags" => %{"iTunSMPB" => smpb}})) == 11_634_168
  end

  test "falls back to the stream duration after the start" do
    # ffprobe applies an edit list to duration_ts; start_pts is the encoder delay.
    assert Trim.valid_samples(probe(%{"duration_ts" => 220_500, "start_pts" => 0})) == 220_500

    assert Trim.valid_samples(probe(%{"duration_ts" => "11636736", "start_pts" => "2112"})) ==
             11_634_624
  end

  test "nothing without usable numbers" do
    assert Trim.valid_samples(probe(%{"duration_ts" => 95_286_370, "start_pts" => "N/A"})) ==
             95_286_370

    assert Trim.valid_samples(probe(%{})) == nil
    assert Trim.valid_samples(probe(%{"duration_ts" => 100, "start_pts" => 100})) == nil
    assert Trim.valid_samples(probe(%{"duration_ts" => 100}, %{"iTunSMPB" => "garbage"})) == 100
  end

  test "only aac sources are trimmed, ffmpeg trims the others itself" do
    assert Trim.valid_samples(probe(%{"codec_name" => "mp3", "duration_ts" => 48_659_940})) == nil
    assert Trim.valid_samples(probe(%{"codec_name" => "flac", "duration_ts" => 1000})) == nil
    assert Trim.valid_samples(%{"streams" => []}) == nil
  end
end
