defmodule MusicBox.Tool.LoudnessTest do
  use ExUnit.Case, async: true

  alias MusicBox.Tool.Loudness

  @fixtures_path Path.expand("../../support/fixtures/music_files", __DIR__)

  describe "exec/1" do
    for fixture <- ~w(
          without_tags/sample.flac
          without_tags/sample.mp3
          without_tags/sample.m4a
          without_tags/sample.ogg
          without_tags/sample.opus
          without_tags/sample.wav
          with_tags/sample.m4a
        ) do
      test "measures #{fixture}" do
        path = Path.join(@fixtures_path, unquote(fixture))

        assert {:ok, %{lufs: lufs, peak: peak}} = Loudness.exec(path)
        assert lufs < 0 and lufs > -70
        assert is_float(peak) and peak < 3
      end
    end

    test "returns an error for non-audio files" do
      path = Path.expand("../../support/fixtures/random.bin", __DIR__)
      assert {:error, :measure_failed} = Loudness.exec(path)
    end
  end

  describe "parse/1" do
    test "parses the ebur128 summary" do
      output = """
      [Parsed_ebur128_0 @ 0x7ad5040180] Summary:

        Integrated loudness:
          I:         -12.2 LUFS
          Threshold: -22.2 LUFS

        Loudness range:
          LRA:        20.1 LU
          Threshold: -32.2 LUFS
          LRA low:   -32.2 LUFS
          LRA high:  -12.2 LUFS

        True peak:
          Peak:        0.3 dBFS
      """

      assert {:ok, %{lufs: -12.2, peak: 0.3}} = Loudness.parse(output)
    end

    test "returns a nil peak for digital silence" do
      output = """
        Integrated loudness:
          I:         -70.0 LUFS
          Threshold:   0.0 LUFS

        True peak:
          Peak:       -inf dBFS
      """

      assert {:ok, %{lufs: -70.0, peak: nil}} = Loudness.parse(output)
    end

    test "returns an error without a summary" do
      assert {:error, :measure_failed} = Loudness.parse("Invalid data found")
    end
  end
end
