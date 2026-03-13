defmodule MusicBox.TranscoderTest do
  use MusicBox.DataCase, async: false

  alias MusicBox.Tracks.Track
  alias MusicBox.Transcoder

  setup :set_mox_global

  setup do
    pid = self()

    stub(MusicBox.Tool.TranscodeMock, :exec, fn args ->
      send(pid, {:transcode_called, args})
      open_port(args)
    end)

    start_supervised!(Transcoder)
    track = Repo.all(Track.preloaded()) |> Enum.random()

    # Files in test database don't have real file paths, so lets
    # use a fixture here.
    fixture_path =
      Path.expand("../support/fixtures/music_files", __DIR__)
      |> Path.join("with_tags/sample.id3v24.mp3")

    file = update_record(track.file, %{path: fixture_path})
    [track: %{track | file: file}]
  end

  describe "transcoder" do
    test "concurrent chunk requests are served independently", %{track: track} do
      preset = hd(Transcoder.Preset.list())

      # Fire off multiple chunk requests
      task1 = Task.async(fn -> Transcoder.request_chunk(track.file, preset, 0) end)
      task2 = Task.async(fn -> Transcoder.request_chunk(track.file, preset, 0) end)

      # Wait for chunks to arrive
      results = Task.await_many([task1, task2], 5_000)
      assert Enum.all?(results, fn {:ok, chunk} -> is_binary(chunk) end)

      path = track.file.path
      assert_receive {:transcode_called, ["-i", ^path | _args]}
    end
  end

  describe "presets" do
    test "preset: mobile_aac", %{track: track} do
      preset = Transcoder.Preset.get(:mobile_aac)
      Transcoder.request_chunk(track.file, preset, 0)

      path = track.file.path
      assert_receive {:transcode_called, args}

      assert [
               "-i",
               ^path,
               "-c:a",
               "aac",
               "-b:a",
               "160k",
               "-ar",
               "48000",
               "-f",
               "adts",
               "-ac",
               "2",
               "pipe:1",
               "-v",
               "quiet",
               "-nostats"
             ] = args
    end

    test "preset: default_aac", %{track: track} do
      preset = Transcoder.Preset.get(:default_aac)
      Transcoder.request_chunk(track.file, preset, 0)

      path = track.file.path
      assert_receive {:transcode_called, args}

      assert [
               "-i",
               ^path,
               "-c:a",
               "aac",
               "-b:a",
               "192k",
               "-ar",
               "48000",
               "-f",
               "adts",
               "-ac",
               "2",
               "pipe:1",
               "-v",
               "quiet",
               "-nostats"
             ] = args
    end

    test "preset: mobile_webm", %{track: track} do
      preset = Transcoder.Preset.get(:mobile_webm)
      Transcoder.request_chunk(track.file, preset, 0)

      path = track.file.path
      duration = to_string(track.file.metadata.duration)
      assert_receive {:transcode_called, args}

      assert [
               "-i",
               ^path,
               "-c:a",
               "libopus",
               "-b:a",
               "128k",
               "-f",
               "webm",
               "-ar",
               "48000",
               "-vn",
               "-fflags",
               "+genpts+nobuffer",
               "-max_delay",
               "0",
               "-avoid_negative_ts",
               "make_zero",
               "-vbr",
               "on",
               "-ss",
               "0",
               "-t",
               ^duration,
               "-cluster_time_limit",
               "4000",
               "-cues_to_front",
               "1",
               "-v",
               "quiet",
               "-nostats",
               "pipe:1"
             ] = args
    end

    test "preset: default_webm", %{track: track} do
      preset = Transcoder.Preset.get(:default_webm)
      Transcoder.request_chunk(track.file, preset, 0)

      path = track.file.path
      duration = to_string(track.file.metadata.duration)

      assert_receive {:transcode_called, args}

      assert [
               "-i",
               ^path,
               "-c:a",
               "libopus",
               "-b:a",
               "160k",
               "-f",
               "webm",
               "-ar",
               "48000",
               "-vn",
               "-fflags",
               "+genpts+nobuffer",
               "-max_delay",
               "0",
               "-avoid_negative_ts",
               "make_zero",
               "-vbr",
               "on",
               "-ss",
               "0",
               "-t",
               ^duration,
               "-cluster_time_limit",
               "4000",
               "-cues_to_front",
               "1",
               "-v",
               "quiet",
               "-nostats",
               "pipe:1"
             ] = args
    end
  end

  defp open_port(args) do
    input_arg_index = Enum.find_index(args, &(&1 == "-i"))
    input_file_path = Enum.at(args, input_arg_index + 1)

    cat_bin = System.find_executable("cat")

    port =
      Port.open(
        {:spawn_executable, cat_bin},
        [
          :binary,
          :stream,
          :exit_status,
          :use_stdio,
          :stderr_to_stdout,
          args: [input_file_path]
        ]
      )

    {:ok, port}
  end
end
