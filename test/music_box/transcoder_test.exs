defmodule MusicBox.TranscoderTest do
  use MusicBox.DataCase, async: false

  alias MusicBox.Tracks.Track
  alias MusicBox.Transcoder

  setup :set_mox_global

  @fixtures_path Path.expand("../support/fixtures/music_files", __DIR__)
  @default_fixture "with_tags/sample.id3v24.mp3"

  @fixtures [
    "with_tags/sample.flac",
    "with_tags/sample.id3v11.mp3",
    "with_tags/sample.id3v22.mp3",
    "with_tags/sample.id3v23.mp3",
    "with_tags/sample.m4a",
    "with_tags/sample.multipage.ogg",
    "with_tags/sample.ogg",
    "without_tags/sample.flac",
    "without_tags/sample.m4a",
    "without_tags/sample.mp3",
    "without_tags/sample.ogg",
    "without_tags/sample.opus",
    "without_tags/sample.wav"
  ]

  setup do
    pid = self()

    MusicBox.Settings.set(%{music_path: @fixtures_path})

    stub(MusicBox.Tool.TranscodeMock, :exec, fn args ->
      send(pid, {:transcode_called, args})
      open_port(args)
    end)

    stub(MusicBox.Tool.ProbeMock, :exec, fn _path ->
      {:ok,
       %{
         "streams" => [
           %{
             "codec_type" => "audio",
             "sample_rate" => 132,
             "duration_ts" => 132,
             "start_pts" => 132,
             "format" => %{},
             "tags" => %{}
           }
         ]
       }}
    end)

    transcoder_pid = start_supervised!(Transcoder)

    on_exit(fn ->
      if :ets.whereis(:transcoder_meta) != :undefined do
        :ets.delete(:transcoder_meta)
      end

      if :ets.whereis(:transcoder_chunks) != :undefined do
        :ets.delete(:transcoder_chunks)
      end
    end)

    # Files in test database don't have real file paths, so lets
    # use a fixture here.
    track =
      Track.preloaded()
      |> Repo.all()
      |> Enum.random()
      |> with_fixture(@default_fixture)

    # Cleanup old transcoded files
    Transcoder.clear_cache()
    File.rm_rf!("./tmp/test")

    [track: track, transcoder_pid: transcoder_pid]
  end

  describe "transcoder" do
    test "concurrent chunk requests are served independently", %{track: track} do
      preset = Transcoder.Preset.default_preset()

      # Fire off multiple chunk requests
      task1 = Task.async(fn -> Transcoder.request_chunk(track.file, preset, 0) end)
      task2 = Task.async(fn -> Transcoder.request_chunk(track.file, preset, 0) end)

      # Wait for chunks to arrive
      results = Task.await_many([task1, task2], 5_000)
      assert Enum.all?(results, fn {:ok, chunk} -> is_binary(chunk) end)

      uri = "file://" <> absolute(track.file.path)
      assert_receive {:transcode_called, ["-i", ^uri | _args]}
    end

    test "get metadata for a transcode job (file and preset)", %{track: track} do
      preset = Transcoder.Preset.default_preset()

      refute Transcoder.get_meta(track.file, preset)

      task = Task.async(fn -> Transcoder.request_chunk(track.file, preset, 0) end)
      assert {:ok, chunk} = Task.await(task)

      assert %Transcoder.Result{
               failed_at: nil,
               chunk_count: 1,
               file_size: 56_204,
               persisted: false
             } = Transcoder.get_meta(track.file, preset)

      # Expect same chunk for same request
      assert {:ok, ^chunk} = Transcoder.request_chunk(track.file, preset, 0)

      assert %Transcoder.Result{
               failed_at: nil,
               chunk_count: 1,
               file_size: 56_204,
               persisted: true
             } = Transcoder.get_meta(track.file, preset)

      # Expect same chunk for same request
      assert {:ok, ^chunk} = Transcoder.request_chunk(track.file, preset, 0)
    end

    test "concurrency with multiple files" do
      # Lets prepare some more tracks with real fixture files
      tracks =
        Track.preloaded()
        |> Repo.all()
        |> Enum.shuffle()
        |> Enum.slice(0, 10)
        |> Enum.with_index()
        |> Enum.map(fn {t, i} ->
          with_fixture(t, Enum.at(@fixtures, i))
        end)

      preset = Transcoder.Preset.default_preset()

      # Fire off multiple chunk requests
      task1 = Task.async(fn -> Transcoder.request_chunk(Enum.at(tracks, 0).file, preset, 0) end)
      task2 = Task.async(fn -> Transcoder.request_chunk(Enum.at(tracks, 1).file, preset, 0) end)
      task3 = Task.async(fn -> Transcoder.request_chunk(Enum.at(tracks, 2).file, preset, 0) end)
      task4 = Task.async(fn -> Transcoder.request_chunk(Enum.at(tracks, 3).file, preset, 0) end)
      task5 = Task.async(fn -> Transcoder.request_chunk(Enum.at(tracks, 4).file, preset, 0) end)
      task6 = Task.async(fn -> Transcoder.request_chunk(Enum.at(tracks, 5).file, preset, 0) end)
      task7 = Task.async(fn -> Transcoder.request_chunk(Enum.at(tracks, 6).file, preset, 0) end)
      task8 = Task.async(fn -> Transcoder.request_chunk(Enum.at(tracks, 7).file, preset, 0) end)
      task9 = Task.async(fn -> Transcoder.request_chunk(Enum.at(tracks, 8).file, preset, 0) end)
      task10 = Task.async(fn -> Transcoder.request_chunk(Enum.at(tracks, 9).file, preset, 0) end)

      # Task 10 should fail because we exceeded transcoder concurrency and queue depth
      assert {:error, :server_busy} = Task.await(task10)

      # Wait for chunks to arrive
      results =
        Task.await_many(
          [task1, task2, task3, task4, task5, task6, task7, task8, task9],
          5_000
        )

      assert Enum.all?(results, fn {:ok, chunk} -> is_binary(chunk) end)
    end

    test "stream chunks until finished", %{track: track} do
      preset = Transcoder.Preset.default_preset()

      refute Transcoder.get_meta(track.file, preset)

      # this specific test file should be done in 1 chunk but we want to test
      # continue stream function too so lets do a few rounds
      Enum.reduce_while(1..5, 0, fn _, chunk ->
        if Transcoder.Utils.continue_stream?(track.file, preset, chunk) do
          Transcoder.request_chunk(track.file, preset, chunk)
          {:cont, chunk + 1}
        else
          {:halt, chunk}
        end
      end)

      assert %Transcoder.Result{
               failed_at: nil,
               chunk_count: 1,
               file_size: 56_204
             } = Transcoder.get_meta(track.file, preset)
    end

    test "fails on unknown chunk", %{track: track} do
      preset = Transcoder.Preset.default_preset()

      # This chunk does not exist
      assert {:error, :no_longer_available} = Transcoder.request_chunk(track.file, preset, 50)
      refute Transcoder.Utils.continue_stream?(track.file, preset, 50)
    end

    test "fails on unknown file", %{track: track} do
      preset = Transcoder.Preset.default_preset()
      file = update_record(track.file, %{path: "does/not/exist.mp3"})

      # This chunk does not exist
      assert {:error, :transcoding_failed} = Transcoder.request_chunk(file, preset, 0)
      refute Transcoder.Utils.continue_stream?(file, preset, 0)
    end

    test "fails on DOWN", %{track: track} do
      preset = Transcoder.Preset.default_preset()

      stub(MusicBox.Tool.TranscodeMock, :exec, fn args ->
        {:ok, port} = open_port(args)
        Process.exit(self(), :kill)
        {:ok, port}
      end)

      assert {:error, :transcoding_failed} = Transcoder.request_chunk(track.file, preset, 0)
    end
  end

  describe "presets" do
    test "preset: mobile_aac", %{track: track} do
      uri = "file://" <> absolute(track.file.path)
      preset = Transcoder.Preset.get(:mobile_aac)
      Transcoder.request_chunk(track.file, preset, 0)

      assert_receive {:transcode_called,
                      [
                        "-i",
                        ^uri,
                        "-c:a",
                        "aac",
                        "-b:a",
                        "128k",
                        "-f",
                        "mp4",
                        "-ar",
                        "44100",
                        "-vn",
                        "-ac",
                        "2",
                        "-y",
                        "-v",
                        "error",
                        "-nostats",
                        _output_file
                      ]}
    end

    test "preset: default_aac", %{track: track} do
      uri = "file://" <> absolute(track.file.path)
      preset = Transcoder.Preset.get(:default_aac)
      Transcoder.request_chunk(track.file, preset, 0)

      assert_receive {:transcode_called,
                      [
                        "-i",
                        ^uri,
                        "-c:a",
                        "aac",
                        "-b:a",
                        "256k",
                        "-f",
                        "mp4",
                        "-ar",
                        "44100",
                        "-vn",
                        "-ac",
                        "2",
                        "-y",
                        "-v",
                        "error",
                        "-nostats",
                        _output_file
                      ]}
    end

    test "preset: mobile_adts", %{track: track} do
      uri = "file://" <> absolute(track.file.path)
      duration = to_string(track.file.metadata.duration)
      preset = Transcoder.Preset.get(:mobile_adts)
      Transcoder.request_chunk(track.file, preset, 0)

      assert_receive {:transcode_called,
                      [
                        "-i",
                        ^uri,
                        "-c:a",
                        "aac",
                        "-b:a",
                        "128k",
                        "-f",
                        "adts",
                        "-ar",
                        "44100",
                        "-vn",
                        "-ac",
                        "2",
                        "-t",
                        ^duration,
                        "-y",
                        "-v",
                        "quiet",
                        "-nostats",
                        "pipe:1"
                      ]}
    end

    test "preset: default_adts", %{track: track} do
      uri = "file://" <> absolute(track.file.path)
      duration = to_string(track.file.metadata.duration)
      preset = Transcoder.Preset.get(:default_adts)
      Transcoder.request_chunk(track.file, preset, 0)

      assert_receive {:transcode_called,
                      [
                        "-i",
                        ^uri,
                        "-c:a",
                        "aac",
                        "-b:a",
                        "256k",
                        "-f",
                        "adts",
                        "-ar",
                        "44100",
                        "-vn",
                        "-ac",
                        "2",
                        "-t",
                        ^duration,
                        "-y",
                        "-v",
                        "quiet",
                        "-nostats",
                        "pipe:1"
                      ]}
    end

    test "preset: mobile_opus", %{track: track} do
      uri = "file://" <> absolute(track.file.path)
      duration = to_string(track.file.metadata.duration)
      preset = Transcoder.Preset.get(:mobile_opus)
      Transcoder.request_chunk(track.file, preset, 0)

      assert_receive {:transcode_called,
                      [
                        "-i",
                        ^uri,
                        "-c:a",
                        "libopus",
                        "-b:a",
                        "96k",
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
                        "-ac",
                        "2",
                        "-ss",
                        "0",
                        "-t",
                        ^duration,
                        "-cluster_time_limit",
                        "4000",
                        "-cues_to_front",
                        "1",
                        "-y",
                        "-v",
                        "quiet",
                        "-nostats",
                        "pipe:1"
                      ]}
    end

    test "preset: default_opus", %{track: track} do
      uri = "file://" <> absolute(track.file.path)
      duration = to_string(track.file.metadata.duration)
      preset = Transcoder.Preset.get(:default_opus)
      Transcoder.request_chunk(track.file, preset, 0)

      assert_receive {:transcode_called,
                      [
                        "-i",
                        ^uri,
                        "-c:a",
                        "libopus",
                        "-b:a",
                        "192k",
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
                        "-ac",
                        "2",
                        "-ss",
                        "0",
                        "-t",
                        ^duration,
                        "-cluster_time_limit",
                        "4000",
                        "-cues_to_front",
                        "1",
                        "-y",
                        "-v",
                        "quiet",
                        "-nostats",
                        "pipe:1"
                      ]}
    end
  end

  describe "aac gapless playback support" do
    test "manual write_smpb test", %{track: track} do
      track = with_fixture(track, "with_tags/sample.m4a")

      # Copy fixture to tmp path because we will write to it.
      tmp_file = Path.join(System.tmp_dir!(), "test_smpb.m4a")
      File.cp!(absolute(track.file.path), tmp_file)
      file = update_record(track.file, %{path: tmp_file})

      # First test calculation
      source_valid_samples = 1234

      assert {:ok, smpb} =
               Transcoder.AACGapless.compute_smpb(file.path, source_valid_samples)

      assert smpb == "00000000 00000400 0002432E 00000000000004D2"

      # Then try writing
      assert :ok = Transcoder.AACGapless.write_smpb(tmp_file, smpb)

      # Verify tag was written via ffprobe
      {output, 0} =
        System.cmd("ffprobe", [
          "-v",
          "quiet",
          "-show_entries",
          "format_tags=iTunSMPB",
          "-of",
          "default=noprint_wrappers=1",
          tmp_file
        ])

      assert String.contains?(output, "iTunSMPB")
      assert String.contains?(output, smpb)

      # Verify file is still valid
      {_, 0} = System.cmd("ffprobe", ["-v", "error", tmp_file])

      # Cleanup
      File.rm!(tmp_file)
    end

    test "transcode pipeline write_smpb test", %{track: track} do
      preset = Transcoder.Preset.get(:mobile_aac)
      track = with_fixture(track, "with_tags/sample.m4a")

      # Copy fixture to tmp path because we will write to it.
      tmp_file = Path.join(System.tmp_dir!(), "test_smpb.m4a")
      File.cp!(absolute(track.file.path), tmp_file)
      file = update_record(track.file, %{path: tmp_file})

      transcoded_file = MusicBox.Transcoder.Cache.File.cache_file_path(file.id, preset)
      refute File.exists?(transcoded_file)
      refute Transcoder.get_meta(file, preset)

      # First test calculation
      assert {:ok, _chunk} = Transcoder.request_chunk(file, preset, 0)

      # wait for persist (happens after chunking is completed)
      assert_eventually(fn -> File.exists?(transcoded_file) end)
      assert %{persisted: true} = Transcoder.get_meta(file, preset)

      # Verify tag was written via ffprobe
      {output, 0} =
        System.cmd("ffprobe", [
          "-v",
          "quiet",
          "-show_entries",
          "format_tags=iTunSMPB",
          "-of",
          "default=noprint_wrappers=1",
          transcoded_file
        ])

      assert String.contains?(output, "iTunSMPB")

      # Verify file is still valid
      {_, 0} = System.cmd("ffprobe", ["-v", "error", transcoded_file])

      # Cleanup
      File.rm!(tmp_file)
      File.rm!(transcoded_file)
    end
  end

  defp with_fixture(track, fixture) do
    file = update_record(track.file, %{path: fixture})
    %{track | file: file}
  end

  defp open_port(args) do
    input_arg_index = Enum.find_index(args, &(&1 == "-i"))
    "file://" <> input_file = Enum.at(args, input_arg_index + 1)

    format_arg_index = Enum.find_index(args, &(&1 == "-f"))
    format = Enum.at(args, format_arg_index + 1)

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
          args: [input_file]
        ]
      )

    if format == "mp4" do
      output_file = List.last(args)
      File.mkdir_p!(Path.dirname(output_file))
      File.cp!(input_file, output_file)
    end

    # # small startup delay simulation
    # :timer.sleep(100)

    {:ok, port}
  end

  defp absolute(path) do
    Path.join(@fixtures_path, path)
  end

  defp assert_eventually(fun, retries \\ 100) do
    if fun.() do
      :ok
    else
      if retries <= 0, do: flunk("assert_eventually timed out")
      :timer.sleep(10)
      assert_eventually(fun, retries - 1)
    end
  end
end
