defmodule Ondu.Transcoder.TrimTest do
  use ExUnit.Case, async: true

  alias Ondu.Transcoder.Trim

  defp probe(stream, format_tags \\ %{}, format_name \\ "mov,mp4,m4a,3gp,3g2,mj2") do
    defaults = %{
      "codec_type" => "audio",
      "codec_name" => "aac",
      "sample_rate" => "44100",
      "time_base" => "1/44100"
    }

    %{
      "streams" => [Map.merge(defaults, stream)],
      "format" => %{"tags" => format_tags, "format_name" => format_name}
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

  test "raw adts has no exact length" do
    assert Trim.valid_samples(
             probe(%{"duration_ts" => 95_286_370, "time_base" => "1/28224000"}, %{}, "aac")
           ) == nil
  end

  test "counts the samples of formats that know their length" do
    assert Trim.valid_samples(
             probe(
               %{
                 "codec_name" => "flac",
                 "duration_ts" => 37_478,
                 "sample_rate" => "11025",
                 "time_base" => "1/11025"
               },
               %{},
               "flac"
             )
           ) == 37_478

    assert Trim.valid_samples(
             probe(
               %{
                 "codec_name" => "pcm_s16le",
                 "duration_ts" => 27_012,
                 "sample_rate" => "22050",
                 "time_base" => "1/22050"
               },
               %{},
               "wav"
             )
           ) == 27_012

    assert Trim.valid_samples(
             probe(%{"codec_name" => "vorbis", "duration_ts" => 149_880}, %{}, "ogg")
           ) == 149_880

    # Opus counts its pre-skip in the duration.
    assert Trim.valid_samples(
             probe(
               %{
                 "codec_name" => "opus",
                 "duration_ts" => 140_160,
                 "sample_rate" => "48000",
                 "time_base" => "1/48000",
                 "initial_padding" => 312
               },
               %{},
               "ogg"
             )
           ) == 139_848
  end

  # ffmpeg only knows an MP3's length from a LAME header, which also gives the
  # start it skips; without one the length is a guess from the bitrate.
  test "mp3 only with a lame header" do
    mp3 = %{"codec_name" => "mp3", "time_base" => "1/14112000", "duration_ts" => 70_560_000}
    assert Trim.valid_samples(probe(Map.put(mp3, "start_pts", 353_600), %{}, "mp3")) == 220_500
    assert Trim.valid_samples(probe(Map.put(mp3, "start_pts", 0), %{}, "mp3")) == nil
    assert Trim.valid_samples(probe(mp3, %{}, "mp3")) == nil
  end

  test "nothing when the time base does not convert to whole samples" do
    assert Trim.valid_samples(
             probe(
               %{"codec_name" => "flac", "duration_ts" => 101, "time_base" => "1/90000"},
               %{},
               "flac"
             )
           ) == nil
  end

  test "the sample rate" do
    assert Trim.sample_rate(probe(%{"sample_rate" => "48000"})) == 48_000
    assert Trim.sample_rate(%{"streams" => []}) == nil
  end

  test "other codecs are not counted" do
    assert Trim.valid_samples(
             probe(%{"codec_name" => "wmav2", "duration_ts" => 1000}, %{}, "asf")
           ) == nil

    assert Trim.valid_samples(%{"streams" => []}) == nil
  end
end
