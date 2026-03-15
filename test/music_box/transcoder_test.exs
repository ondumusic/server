defmodule MusicBox.TranscoderTest do
  use MusicBox.DataCase, async: false

  alias MusicBox.Tracks.Track
  alias MusicBox.Transcoder

  setup :set_mox_global

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

    stub(MusicBox.Tool.TranscodeMock, :exec, fn args ->
      send(pid, {:transcode_called, args})
      open_port(args)
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
    File.rm_rf!("./tmp")

    [track: track, transcoder_pid: transcoder_pid]
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

    test "get metadata for a transcode job (file and preset)", %{track: track} do
      preset = hd(Transcoder.Preset.list())

      refute Transcoder.get_meta(track.file, preset)
      assert {:ok, chunk} = Transcoder.request_chunk(track.file, preset, 0)

      assert %Transcoder.Result{
               failed_at: nil,
               chunk_count: 1,
               file_size: 56_204,
               persisted: false
             } = Transcoder.get_meta(track.file, preset)

      assert {:ok, ^chunk} = Transcoder.request_chunk(track.file, preset, 0)

      assert %Transcoder.Result{
               failed_at: nil,
               chunk_count: 1,
               file_size: 56_204,
               persisted: true
             } = Transcoder.get_meta(track.file, preset)

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

      preset = hd(Transcoder.Preset.list())

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
      preset = hd(Transcoder.Preset.list())

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
      preset = hd(Transcoder.Preset.list())

      # This chunk does not exist
      assert {:error, :no_longer_available} = Transcoder.request_chunk(track.file, preset, 50)
      refute Transcoder.Utils.continue_stream?(track.file, preset, 50)
    end

    test "fails on unknown file", %{track: track} do
      preset = hd(Transcoder.Preset.list())
      file = update_record(track.file, %{path: "does/not/exist.mp3"})

      # This chunk does not exist
      assert {:error, :transcoding_failed} = Transcoder.request_chunk(file, preset, 0)
      refute Transcoder.Utils.continue_stream?(file, preset, 0)
    end

    test "fails on DOWN", %{track: track} do
      preset = hd(Transcoder.Preset.list())

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
      preset = Transcoder.Preset.get(:mobile_aac)
      Transcoder.request_chunk(track.file, preset, 0)

      path = track.file.path
      duration = to_string(track.file.metadata.duration)

      assert_receive {:transcode_called,
                      [
                        "-i",
                        ^path,
                        "-c:a",
                        "aac",
                        "-b:a",
                        "160k",
                        "-ar",
                        "48000",
                        "-f",
                        "mp4",
                        "-vn",
                        "-ac",
                        "2",
                        "-movflags",
                        "frag_keyframe+empty_moov+default_base_moof",
                        "pipe:1",
                        "-v",
                        "quiet",
                        "-nostats",
                        "-t",
                        ^duration
                      ]}
    end

    test "preset: default_aac", %{track: track} do
      preset = Transcoder.Preset.get(:default_aac)
      Transcoder.request_chunk(track.file, preset, 0)

      path = track.file.path
      duration = to_string(track.file.metadata.duration)

      assert_receive {:transcode_called,
                      [
                        "-i",
                        ^path,
                        "-c:a",
                        "aac",
                        "-b:a",
                        "192k",
                        "-ar",
                        "48000",
                        "-f",
                        "mp4",
                        "-vn",
                        "-ac",
                        "2",
                        "-movflags",
                        "frag_keyframe+empty_moov+default_base_moof",
                        "pipe:1",
                        "-v",
                        "quiet",
                        "-nostats",
                        "-t",
                        ^duration
                      ]}
    end

    test "preset: mobile_webm", %{track: track} do
      preset = Transcoder.Preset.get(:mobile_webm)
      Transcoder.request_chunk(track.file, preset, 0)

      path = track.file.path
      duration = to_string(track.file.metadata.duration)

      assert_receive {:transcode_called,
                      [
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
                      ]}
    end

    test "preset: default_webm", %{track: track} do
      preset = Transcoder.Preset.get(:default_webm)
      Transcoder.request_chunk(track.file, preset, 0)

      path = track.file.path
      duration = to_string(track.file.metadata.duration)

      assert_receive {:transcode_called,
                      [
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
                      ]}
    end
  end

  defp with_fixture(track, fixture) do
    # Files in test database don't have real file paths, so lets
    # use a fixture here.
    fixture_path =
      Path.expand("../support/fixtures/music_files", __DIR__)
      |> Path.join(fixture)

    file = update_record(track.file, %{path: fixture_path})
    %{track | file: file}
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

    # small startup delay simulation
    :timer.sleep(100)

    {:ok, port}
  end
end
