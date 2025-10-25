defmodule MusicBox.FileScannerTest do
  use MusicBox.DataCase, async: false

  setup :set_mox_global
  setup :verify_on_exit!

  alias MusicBox.FileScanner
  alias MusicBox.FileScanner.Entry
  alias MusicBox.FileScanner.Pipeline
  alias MusicBox.FileScanner.Producer
  alias MusicBox.Settings

  @fixtures_path Path.expand("../support/fixtures/music_files", __DIR__)

  defmodule TestConsumer do
    # <- Don't forget this!
    use GenStage

    def start_link(producer) do
      GenStage.start_link(__MODULE__, {producer, self()})
    end

    def init({producer, test_pid}) do
      {:consumer, test_pid, subscribe_to: [producer]}
    end

    def handle_events(events, _from, test_pid) do
      send(test_pid, {:events, events})
      {:noreply, [], test_pid}
    end
  end

  describe "filescanner" do
    test "cannot start scan if music_path not configured" do
      assert {:error, :missing_music_path} = FileScanner.scan()
    end

    test "cannot start scan if producer not found" do
      Settings.set(%{music_path: @fixtures_path})
      assert {:error, :no_producer_found} = FileScanner.scan()
    end
  end

  describe "pipeline" do
    setup do
      MusicBox.Settings.set(%{music_path: @fixtures_path})
      start_supervised!({Pipeline, auto_start: false})
      :ok
    end

    test "can scan mp3 file without tags" do
      entry =
        %Entry{
          path: Path.join(@fixtures_path, "without_tags/sample.mp3"),
          is_dir: false
        }

      expect_probe(fn _path ->
        {:ok, %{format: %{duration: "3.448125"}}}
      end)

      ref = Broadway.test_message(Pipeline, entry, metadata: [scan_type: :full])
      assert_receive {:ack, ^ref, [%{data: data}], []}
      assert data.path == entry.path
      assert data.type == :mp3
      assert data.size == 55_170
      assert data.checksum == "1392cce60f3309ed44d089500ae92e77dc5c966a"
      assert data.last_modified_at
      refute data.metadata.artist
      refute data.metadata.album
      refute data.metadata.title
      refute data.metadata.track
      refute data.metadata.release_year
      assert data.metadata.duration == 3.448125
      assert data.metadata.genres == []
    end

    test "can scan files with tags" do
      files = [
        Path.join(@fixtures_path, "with_tags/sample.id3v11.mp3"),
        Path.join(@fixtures_path, "with_tags/sample.m4a"),
        Path.join(@fixtures_path, "with_tags/sample.flac"),
        Path.join(@fixtures_path, "with_tags/sample.multipage.ogg"),
        Path.join(@fixtures_path, "with_tags/sample.id3v22.mp3"),
        Path.join(@fixtures_path, "with_tags/sample.ogg"),
        Path.join(@fixtures_path, "with_tags/sample.id3v23.mp3"),
        Path.join(@fixtures_path, "with_tags/sample.id3v24.mp3")
      ]

      for path <- files do
        entry = %Entry{path: path, is_dir: false}

        expect_probe(fn ^path ->
          {:ok,
           %{
             format: %{
               tags: %{
                 artist: "Test Artist",
                 album: "Test Album",
                 title: "Test Title",
                 genre: "Jazz",
                 date: "2000-01-01",
                 track: "3"
               }
             }
           }}
        end)

        ref = Broadway.test_message(Pipeline, entry, metadata: [scan_type: :full])
        assert_receive {:ack, ^ref, [%{data: data}], []}
        assert data.path == entry.path

        assert %{
                 artist: "Test Artist",
                 album: "Test Album",
                 title: "Test Title",
                 track: 3,
                 release_year: 2000,
                 genres: ["Jazz"]
               } = data.metadata
      end
    end

    test "understands multiple music file types" do
      files = [
        {:mp3, Path.join(@fixtures_path, "without_tags/sample.mp3")},
        {:m4a, Path.join(@fixtures_path, "without_tags/sample.m4a")},
        {:flac, Path.join(@fixtures_path, "without_tags/sample.flac")},
        {:ogg, Path.join(@fixtures_path, "without_tags/sample.ogg")},
        {:opus, Path.join(@fixtures_path, "without_tags/sample.opus")},
        {:wav, Path.join(@fixtures_path, "without_tags/sample.wav")},
        {:mp3, Path.join(@fixtures_path, "with_tags/sample.id3v11.mp3")},
        {:m4a, Path.join(@fixtures_path, "with_tags/sample.m4a")},
        {:flac, Path.join(@fixtures_path, "with_tags/sample.flac")},
        {:ogg, Path.join(@fixtures_path, "with_tags/sample.multipage.ogg")},
        {:mp3, Path.join(@fixtures_path, "with_tags/sample.id3v22.mp3")},
        {:ogg, Path.join(@fixtures_path, "with_tags/sample.ogg")},
        {:mp3, Path.join(@fixtures_path, "with_tags/sample.id3v23.mp3")},
        {:mp3, Path.join(@fixtures_path, "with_tags/sample.id3v24.mp3")}
      ]

      for {type, path} <- files do
        entry = %Entry{path: path, is_dir: false}
        expect_probe(fn ^path -> {:ok, %{}} end)

        ref = Broadway.test_message(Pipeline, entry, metadata: [scan_type: :full])
        assert_receive {:ack, ^ref, [%{data: data}], []}
        assert data.path == entry.path
        assert data.type == type
      end
    end

    test "ignores non-music files" do
      files = [
        Path.join(@fixtures_path, "README.md"),
        Path.join(@fixtures_path, "random.bin")
      ]

      for path <- files do
        entry = %Entry{path: path, is_dir: false}
        ref = Broadway.test_message(Pipeline, entry, metadata: [scan_type: :full])
        assert_receive {:ack, ^ref, [], [failed]}
        assert failed.status == {:failed, :is_unknown}
      end
    end

    test "skips existing files when doing a quick scan" do
      path = Path.join(@fixtures_path, "with_tags/sample.m4a")
      entry = %Entry{path: path, is_dir: false}

      expect_probe(fn ^path -> {:ok, %{}} end)

      ref = Broadway.test_message(Pipeline, entry, metadata: [scan_type: :quick])
      assert_receive {:ack, ^ref, [%{data: data} = message], []}
      Pipeline.ack(:default, [message], [])
      assert data.path == entry.path
      assert file = Repo.get_by(MusicBox.Files.File, path: entry.path)

      # Second run
      entry = %Entry{path: path, is_dir: false}
      ref = Broadway.test_message(Pipeline, entry, metadata: [scan_type: :quick])
      assert_receive {:ack, ^ref, [], [message]}
      Pipeline.ack(:default, [], [message])
      assert message.status == {:failed, :is_exists}
      assert ^file = Repo.get_by(MusicBox.Files.File, path: entry.path)
    end
  end

  describe "producer" do
    test "produces file and directory entries" do
      MusicBox.Settings.set(%{music_path: @fixtures_path})
      start_producer_consumer()

      expected = [
        %Entry{
          path: Path.join(@fixtures_path, "README.md"),
          is_dir: false
        },
        %Entry{
          path: Path.join(@fixtures_path, "with_tags"),
          is_dir: true
        },
        %Entry{
          path: Path.join(@fixtures_path, "without_tags"),
          is_dir: true
        }
      ]

      assert_entries(expected)
    end

    test "can dive deeper into directories in batches" do
      MusicBox.Settings.set(%{music_path: @fixtures_path})
      {producer, _consumer} = start_producer_consumer()

      assert_receive {:events, events}
      path_entries = Enum.filter(events, & &1.is_dir)
      GenStage.call(producer, {:walk, path_entries})

      expected = [
        %MusicBox.FileScanner.Entry{
          path: Path.join(@fixtures_path, "with_tags/sample.flac"),
          is_dir: false
        },
        %MusicBox.FileScanner.Entry{
          path: Path.join(@fixtures_path, "with_tags/sample.id3v11.mp3"),
          is_dir: false
        },
        %MusicBox.FileScanner.Entry{
          path: Path.join(@fixtures_path, "with_tags/sample.id3v22.mp3"),
          is_dir: false
        },
        %MusicBox.FileScanner.Entry{
          path: Path.join(@fixtures_path, "with_tags/sample.id3v23.mp3"),
          is_dir: false
        },
        %MusicBox.FileScanner.Entry{
          path: Path.join(@fixtures_path, "with_tags/sample.id3v24.mp3"),
          is_dir: false
        },
        %MusicBox.FileScanner.Entry{
          path: Path.join(@fixtures_path, "with_tags/sample.m4a"),
          is_dir: false
        },
        %MusicBox.FileScanner.Entry{
          path: Path.join(@fixtures_path, "with_tags/sample.multipage.ogg"),
          is_dir: false
        },
        %MusicBox.FileScanner.Entry{
          path: Path.join(@fixtures_path, "with_tags/sample.ogg"),
          is_dir: false
        },
        %MusicBox.FileScanner.Entry{
          path: Path.join(@fixtures_path, "without_tags/sample.flac"),
          is_dir: false
        },
        %MusicBox.FileScanner.Entry{
          path: Path.join(@fixtures_path, "without_tags/sample.m4a"),
          is_dir: false
        },
        %MusicBox.FileScanner.Entry{
          path: Path.join(@fixtures_path, "without_tags/sample.mp3"),
          is_dir: false
        },
        %MusicBox.FileScanner.Entry{
          path: Path.join(@fixtures_path, "without_tags/sample.ogg"),
          is_dir: false
        },
        %MusicBox.FileScanner.Entry{
          path: Path.join(@fixtures_path, "without_tags/sample.opus"),
          is_dir: false
        },
        %MusicBox.FileScanner.Entry{
          path: Path.join(@fixtures_path, "without_tags/sample.wav"),
          is_dir: false
        }
      ]

      assert_entries(expected)
    end
  end

  defp start_producer_consumer(opts \\ []) do
    auto_start = Keyword.get(opts, :auto_start, false)
    {:ok, producer} = start_supervised({Producer, auto_start: auto_start})
    {:ok, consumer} = TestConsumer.start_link(producer)

    refute_receive {:events, _}, 200
    GenStage.call(producer, :start)
    {producer, consumer}
  end

  defp assert_entries(entries) do
    assert_receive {:events, events}

    for entry <- entries do
      assert entry in events
    end
  end

  defp expect_probe(fun) do
    expect(MusicBox.Tool.ProbeMock, :exec, fn path ->
      case fun.(path) do
        {:ok, result} ->
          {:ok,
           result
           |> JSON.encode!()
           |> JSON.decode!()}

        error ->
          error
      end
    end)
  end
end
