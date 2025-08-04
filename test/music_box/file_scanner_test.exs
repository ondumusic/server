defmodule MusicBox.FileScannerTest do
  use MusicBox.DataCase

  alias MusicBox.FileScanner
  alias MusicBox.FileScanner.Pipeline
  alias MusicBox.FileScanner.Producer
  alias MusicBox.FileScanner.Entry

  @fixtures_path Path.expand("../support/fixtures/music_files", __DIR__)

  defmodule TestConsumer do
    def start_link(producer) do
      GenStage.start_link(__MODULE__, {producer, self()})
    end

    def init({producer, owner}) do
      {:consumer, owner, subscribe_to: [{producer, min_demand: 0, max_demand: 3}]}
    end

    def handle_events(events, _from, owner) do
      send(owner, {:received, events})
      {:noreply, [], owner}
    end
  end

  describe "filescanner" do
    test "can be started and stopped" do
      assert {:ok, pid} = FileScanner.scan(@fixtures_path)
      assert {:error, {:already_started, ^pid}} = FileScanner.scan(@fixtures_path)
      assert Process.alive?(pid)
      FileScanner.stop()
      refute Process.alive?(pid)
    end
  end

  describe "pipeline" do
    setup do
      start_supervised!({Pipeline, [path: @fixtures_path]})
      :ok
    end

    test "can scan mp3 file without tags" do
      entry =
        %Entry{
          path: Path.join(@fixtures_path, "without_tags/sample.mp3"),
          is_dir: false
        }

      ref = Broadway.test_message(Pipeline, entry, metadata: [scan_type: :full])
      assert_receive {:ack, ^ref, [%{data: data}], []}
      assert data.path == entry.path
      assert data.type == :mp3
      assert data.size == 55170
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
      entry = %Entry{path: Path.join(@fixtures_path, "with_tags/sample.m4a"), is_dir: false}
      ref = Broadway.test_message(Pipeline, entry, metadata: [scan_type: :quick])
      assert_receive {:ack, ^ref, [%{data: data} = message], []}
      Pipeline.ack(:default, [message], [])
      assert data.path == entry.path
      assert file = Repo.get_by(MusicBox.Files.File, path: entry.path)

      # Second run
      entry = %Entry{path: Path.join(@fixtures_path, "with_tags/sample.m4a"), is_dir: false}
      ref = Broadway.test_message(Pipeline, entry, metadata: [scan_type: :quick])
      assert_receive {:ack, ^ref, [], [message]}
      Pipeline.ack(:default, [], [message])
      assert message.status == {:failed, :is_exists}
      assert ^file = Repo.get_by(MusicBox.Files.File, path: entry.path)
    end
  end

  describe "producer" do
    test "produces file and directory entries" do
      {:ok, producer} = start_supervised({Producer, @fixtures_path})
      {:ok, _cons} = TestConsumer.start_link(producer)

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

      assert_receive {:received, ^expected}
    end

    test "can dive deeper into directories in batches" do
      {:ok, producer} = start_supervised({Producer, @fixtures_path})
      {:ok, _cons} = TestConsumer.start_link(producer)
      assert_receive {:received, events}
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

      for expected_batch <- Enum.chunk_every(expected, 3) do
        assert_receive {:received, ^expected_batch}
      end
    end
  end
end
