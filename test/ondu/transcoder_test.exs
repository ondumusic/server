defmodule Ondu.TranscoderTest do
  use Ondu.DataCase, async: false

  alias Ondu.Tool
  alias Ondu.Tracks.Track
  alias Ondu.Transcoder

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

    Ondu.Settings.set(%{music_path: @fixtures_path})

    stub(Tool.TranscodeMock, :exec, fn args ->
      send(pid, {:transcode_called, args})
      open_port(args)
    end)

    # Nothing to trim, unless a test says otherwise.
    stub(Tool.ProbeMock, :exec, fn _path -> {:error, :probe_failed} end)

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
      preset = Transcoder.Preset.get(:mobile_ogg)

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
      preset = Transcoder.Preset.get(:mobile_ogg)

      refute Transcoder.get_meta(track.file, preset)

      task = Task.async(fn -> Transcoder.request_chunk(track.file, preset, 0) end)
      assert {:ok, chunk} = Task.await(task)

      # The chunk is served before the job completes, wait for it to be persisted
      assert_eventually(fn ->
        match?(%{persisted: true}, Transcoder.get_meta(track.file, preset))
      end)

      size = Transcoder.Preset.predicted_size(track.file, preset)
      chunks = ceil(size / Transcoder.Utils.chunk_size())

      assert %Transcoder.Result{
               failed_at: nil,
               chunk_count: ^chunks,
               file_size: ^size,
               persisted: true
             } = Transcoder.get_meta(track.file, preset)

      # Expect same chunk for same request
      assert {:ok, ^chunk} = Transcoder.request_chunk(track.file, preset, 0)
    end

    test "transcodes a file again when its content changed after it was transcoded", %{
      track: track
    } do
      preset = Transcoder.Preset.get(:mobile_ogg)
      cache_path = Transcoder.Cache.cache_file_path(track.file.id, preset)

      assert {:ok, _chunk} = Transcoder.request_chunk(track.file, preset, 0)
      assert_receive {:transcode_called, _args}

      assert_eventually(fn ->
        match?(%{persisted: true}, Transcoder.get_meta(track.file, preset))
      end)

      # Unchanged files keep their transcode.
      file = %{track.file | content_changed_at: ~U[2000-01-01 00:00:00Z]}
      assert %{persisted: true} = Transcoder.get_meta(file, preset)
      assert File.exists?(cache_path)

      # Changed after it was transcoded.
      file = %{track.file | content_changed_at: DateTime.add(DateTime.utc_now(:second), 60)}
      refute Transcoder.get_meta(file, preset)
      refute File.exists?(cache_path)

      assert {:ok, _chunk} = Transcoder.request_chunk(file, preset, 0)
      assert_receive {:transcode_called, _args}
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

      preset = Transcoder.Preset.get(:mobile_ogg)

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
      preset = Transcoder.Preset.get(:mobile_ogg)

      refute Transcoder.get_meta(track.file, preset)

      size = Transcoder.Preset.predicted_size(track.file, preset)
      chunks = ceil(size / Transcoder.Utils.chunk_size())

      # Keep asking for the next chunk until the stream says it is done.
      last =
        Enum.reduce_while(0..(chunks + 5), 0, fn chunk, _ ->
          if Transcoder.Utils.continue_stream?(track.file, preset, chunk) do
            assert {:ok, _data} = Transcoder.request_chunk(track.file, preset, chunk)
            {:cont, chunk + 1}
          else
            {:halt, chunk}
          end
        end)

      assert last == chunks

      assert %Transcoder.Result{failed_at: nil, chunk_count: ^chunks, file_size: ^size} =
               Transcoder.get_meta(track.file, preset)
    end

    test "fails on unknown chunk", %{track: track} do
      preset = Transcoder.Preset.get(:mobile_ogg)

      # This chunk does not exist
      assert {:error, :no_longer_available} = Transcoder.request_chunk(track.file, preset, 50)
      refute Transcoder.Utils.continue_stream?(track.file, preset, 50)
    end

    test "fails on unknown file", %{track: track} do
      preset = Transcoder.Preset.get(:mobile_ogg)
      file = update_record(track.file, %{path: "does/not/exist.mp3"})

      # This chunk does not exist
      assert {:error, :transcoding_failed} = Transcoder.request_chunk(file, preset, 0)
      refute Transcoder.Utils.continue_stream?(file, preset, 0)
    end

    test "fails on DOWN", %{track: track} do
      preset = Transcoder.Preset.get(:mobile_ogg)

      stub(Tool.TranscodeMock, :exec, fn args ->
        {:ok, port} = open_port(args)
        Process.exit(self(), :kill)
        {:ok, port}
      end)

      assert {:error, :transcoding_failed} = Transcoder.request_chunk(track.file, preset, 0)
    end
  end

  describe "presets" do
    test "preset: default_ogg", %{track: track} do
      uri = "file://" <> absolute(track.file.path)
      preset = Transcoder.Preset.get(:default_ogg)
      Transcoder.request_chunk(track.file, preset, 0)

      assert_receive {:transcode_called,
                      [
                        "-i",
                        ^uri,
                        "-c:a",
                        "libopus",
                        "-b:a",
                        "192k",
                        "-vbr",
                        "off",
                        "-f",
                        "ogg",
                        "-ar",
                        "48000",
                        "-vn",
                        "-ac",
                        "2",
                        "-map_metadata",
                        "-1",
                        "-y",
                        "-v",
                        "quiet",
                        "-nostats",
                        "pipe:1"
                      ]}
    end

    test "preset: mobile_ogg", %{track: track} do
      preset = Transcoder.Preset.get(:mobile_ogg)
      Transcoder.request_chunk(track.file, preset, 0)

      assert_receive {:transcode_called, args}

      assert ["-c:a", "libopus", "-b:a", "96k", "-vbr", "off", "-f", "ogg" | _] =
               Enum.drop(args, 2)
    end

    test "cuts the end padding of aac sources", %{track: track} do
      stub(Tool.ProbeMock, :exec, fn _path ->
        {:ok,
         %{
           "streams" => [%{"codec_type" => "audio", "codec_name" => "aac", "duration_ts" => 1}],
           "format" => %{
             "tags" => %{"iTunSMPB" => " 00000000 00000840 000001C8 0000000000B185F8"}
           }
         }}
      end)

      Transcoder.request_chunk(track.file, Transcoder.Preset.get(:default_ogg), 0)

      assert_receive {:transcode_called, ["-i", _uri, "-af", "atrim=end_sample=11634168" | _]}
    end

    test "the default preset is default_ogg" do
      assert %{id: :default_ogg} = Transcoder.Preset.default_preset()
      assert %{id: :mobile_ogg} = Transcoder.Preset.get("mobile_ogg")
      assert Transcoder.Preset.get("nonsense") == nil
    end

    test "pads the output up to the predicted size", %{track: track} do
      preset = Transcoder.Preset.get(:default_ogg)
      file = track.file
      predicted = Transcoder.Preset.predicted_size(file, preset)
      fixture_size = File.stat!(absolute(file.path)).size
      assert fixture_size < predicted

      assert {:ok, chunk} = Transcoder.request_chunk(file, preset, 0)

      assert_eventually(fn ->
        match?(%{completed_at: c} when c != nil, Transcoder.get_meta(file, preset))
      end)

      assert %{file_size: ^predicted, chunk_count: chunk_count} =
               Transcoder.get_meta(file, preset)

      assert chunk_count == ceil(predicted / Transcoder.Utils.chunk_size())

      # The real output comes first, then zeros.
      assert binary_part(chunk, 0, 16) == binary_part(File.read!(absolute(file.path)), 0, 16)
      {:ok, last} = Transcoder.request_chunk(file, preset, chunk_count - 1)
      assert last == :binary.copy(<<0>>, byte_size(last))
    end

    # A file whose stored duration is too short (a headerless VBR MP3 is probed
    # by its first frames) would otherwise fail on every play, since a failed
    # transcode is never cached. Finishing it with its real size cuts the first
    # listeners short once; every play after that is exact from the cache.
    test "finishes with the real size when the output exceeds the predicted size", %{
      track: track
    } do
      preset = Transcoder.Preset.get(:mobile_ogg)
      # A track that claims to be half a second long, while the fixture is not.
      file = %{track.file | metadata: %{track.file.metadata | duration: 0.5}}
      fixture_size = File.stat!(absolute(file.path)).size
      assert Transcoder.Preset.predicted_size(file, preset) < fixture_size

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          Transcoder.request_chunk(file, preset, 0)

          assert_eventually(fn ->
            match?(%{completed_at: c} when c != nil, Transcoder.get_meta(file, preset))
          end)
        end)

      assert %{file_size: ^fixture_size, failed_at: nil} = Transcoder.get_meta(file, preset)
      assert log =~ "exceeds the predicted size"
    end
  end

  describe "presets with the real ffmpeg" do
    @describetag :ffmpeg

    setup do
      stub(Tool.TranscodeMock, :exec, &Tool.Transcode.exec/1)
      stub(Tool.ProbeMock, :exec, &Tool.Probe.exec/1)
      :ok
    end

    # An album track from an AAC source: ffmpeg leaves the encoder padding at
    # its end, which would click at the next track. Built here from the flac
    # fixture, since the fixtures carry no padding information; ffmpeg's own
    # edit list is what says where the music ends.
    test "transcodes of aac sources end where the music ends", %{track: track} do
      source =
        Path.join(System.tmp_dir!(), "padded-source-#{System.unique_integer([:positive])}.m4a")

      flac = absolute("with_tags/sample.flac")

      {_, 0} =
        System.cmd(
          "ffmpeg",
          ~w(-nostdin -v error -y -i #{flac} -c:a aac -b:a 128k -ar 44100) ++ [source]
        )

      # Where the music ends according to the source's edit list, in its samples.
      {valid, ""} =
        "ffprobe"
        |> System.cmd(~w(-v error -show_entries stream=duration_ts -of csv=p=0) ++ [source])
        |> elem(0)
        |> String.trim()
        |> Integer.parse()

      preset = Transcoder.Preset.get(:mobile_ogg)
      file = track |> with_fixture(source) |> Map.fetch!(:file) |> with_probed_duration()
      cache_file = Transcoder.Cache.cache_file_path(file.id, preset)
      assert {:ok, _chunk} = Transcoder.request_chunk(file, preset, 0)
      assert_eventually(fn -> File.exists?(cache_file) end, 500)

      {pcm, 0} =
        System.cmd(
          "ffmpeg",
          ~w(-nostdin -v error -i #{cache_file} -f s16le -ac 1 -ar 44100 pipe:1)
        )

      assert_in_delta div(byte_size(pcm), 2), valid, 2
      File.rm!(source)
    end

    # The whole point of the Ogg presets: the prediction is an upper bound for
    # every fixture, and not a wasteful one.
    test "predicts the size of every fixture", %{track: track} do
      for fixture <- @fixtures, preset_id <- [:default_ogg, :mobile_ogg] do
        preset = Transcoder.Preset.get(preset_id)
        file = track |> with_fixture(fixture) |> Map.fetch!(:file) |> with_probed_duration()

        # Encode outside of the transcoder, to compare with the unpadded size.
        args = Transcoder.Preset.ffmpeg_args(file, preset)
        {output, 0} = System.cmd("ffmpeg", ["-nostdin" | args])
        actual = byte_size(output)
        predicted = Transcoder.Preset.predicted_size(file, preset)

        assert actual <= predicted, "#{fixture} #{preset_id}: #{actual} > #{predicted}"

        assert predicted - actual < 3 * Transcoder.Preset.bitrate(file, preset) * 125 + 2048,
               "#{fixture} #{preset_id}: padding of #{predicted - actual} bytes is too much"
      end
    end

    # The padding is made of empty pages, so the duration survives it even when
    # the padding is far larger than the 64 KB ffmpeg (and Chrome) scan for the
    # last page. Forced here by claiming a duration well past the music.
    test "a transcode padded far past its music keeps its duration", %{track: track} do
      preset = Transcoder.Preset.get(:default_ogg)

      file =
        track
        |> with_fixture("with_tags/sample.flac")
        |> Map.fetch!(:file)
        |> with_probed_duration()

      real_duration = file.metadata.duration
      file = %{file | metadata: %{file.metadata | duration: real_duration + 20}}
      cache_file = Transcoder.Cache.cache_file_path(file.id, preset)

      assert {:ok, _chunk} = Transcoder.request_chunk(file, preset, 0)
      assert_eventually(fn -> File.exists?(cache_file) end, 500)
      assert File.stat!(cache_file).size == Transcoder.Preset.predicted_size(file, preset)
      assert File.stat!(cache_file).size > 64 * 1024 + 20 * 24_000

      {output, 0} =
        System.cmd(
          "ffprobe",
          ~w(-v error -show_entries format=duration -of csv=p=0) ++ [cache_file]
        )

      assert_in_delta String.to_float(String.trim(output)), real_duration, 0.1
    end

    test "the padded transcode is still a valid opus file", %{track: track} do
      preset = Transcoder.Preset.get(:mobile_ogg)

      file =
        track
        |> with_fixture("with_tags/sample.flac")
        |> Map.fetch!(:file)
        |> with_probed_duration()

      cache_file = Transcoder.Cache.cache_file_path(file.id, preset)

      assert {:ok, _chunk} = Transcoder.request_chunk(file, preset, 0)
      assert_eventually(fn -> File.exists?(cache_file) end, 500)
      assert File.stat!(cache_file).size == Transcoder.Preset.predicted_size(file, preset)

      {output, 0} =
        System.cmd(
          "ffprobe",
          ~w(-v error -show_entries stream=codec_name:format=duration -of default=nw=1) ++
            [cache_file]
        )

      assert output =~ "codec_name=opus"
      assert [duration] = Regex.run(~r/duration=([\d.]+)/, output, capture: :all_but_first)
      assert_in_delta String.to_float(duration), file.metadata.duration, 0.1
    end

    # The tracks in the test database have made up durations, the prediction
    # needs the real one.
    defp with_probed_duration(file) do
      {output, 0} =
        System.cmd(
          "ffprobe",
          ~w(-v error -show_entries format=duration -of csv=p=0) ++ [absolute(file.path)]
        )

      %{file | metadata: %{file.metadata | duration: String.to_float(String.trim(output))}}
    end
  end

  defp with_fixture(track, fixture) do
    file = update_record(track.file, %{path: fixture})
    %{track | file: file}
  end

  defp open_port(args) do
    input_arg_index = Enum.find_index(args, &(&1 == "-i"))
    "file://" <> input_file = Enum.at(args, input_arg_index + 1)

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

    # # small startup delay simulation
    # :timer.sleep(100)

    {:ok, port}
  end

  defp absolute("/" <> _ = path), do: path
  defp absolute(path), do: Path.join(@fixtures_path, path)
end
