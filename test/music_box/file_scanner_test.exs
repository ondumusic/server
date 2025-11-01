defmodule MusicBox.FileScannerTest do
  use MusicBox.DataCase, async: false

  setup :set_mox_global
  # setup :verify_on_exit!

  alias MusicBox.FileScanner
  alias MusicBox.FileScanner.Analyzer
  alias MusicBox.FileScanner.Walker
  alias MusicBox.Settings

  @fixtures_path Path.expand("../support/fixtures/music_files", __DIR__)

  test "cannot start scan if music_path not configured" do
    assert {:error, :missing_music_path} = FileScanner.scan()
  end

  describe "filescanner" do
    setup do
      Settings.set(%{music_path: @fixtures_path})
      start_supervised!(FileScanner.Supervisor)

      Phoenix.PubSub.subscribe(MusicBox.PubSub, "library:updated")

      on_exit(fn ->
        Phoenix.PubSub.unsubscribe(MusicBox.PubSub, "library:updated")
      end)

      stub_probe(fn _path ->
        {:ok,
         %{
           format: %{
             duration: "3.448125",
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

      :ok
    end

    test "cannot start twice" do
      FileScanner.Agent.start(:full)
      assert {:error, :already_running} = FileScanner.scan(:full)
    end

    test "skips existing files when doing a quick scan" do
      assert {:ok, :scan_completed} = FileScanner.scan(:full)
      file_count = Repo.aggregate(MusicBox.Files.File, :count)
      assert_receive %{topic: "library:updated", payload: payload}
      assert [_album_id] = payload.albums
      assert [_artist_id] = payload.artists

      assert {:ok, :scan_completed} = FileScanner.scan(:quick)
      new_file_count = Repo.aggregate(MusicBox.Files.File, :count)
      assert file_count == new_file_count
      refute_receive %{topic: "library:updated"}, 200
    end

    test "rescans existing files when doing a full scan" do
      assert {:ok, :scan_completed} = FileScanner.scan(:full)
      file_count = Repo.aggregate(MusicBox.Files.File, :count)
      assert_receive %{topic: "library:updated", payload: payload}
      assert [_album_id] = payload.albums
      assert [_artist_id] = payload.artists

      assert {:ok, :scan_completed} = FileScanner.scan(:full)
      new_file_count = Repo.aggregate(MusicBox.Files.File, :count)
      assert file_count == new_file_count
      assert_receive %{topic: "library:updated", payload: payload}
      assert [_album_id] = payload.albums
      assert [_artist_id] = payload.artists
    end

    test "can start async" do
      {:ok, :scan_started} = FileScanner.scan_async(:full)
      assert_receive %{topic: "library:updated", payload: payload}
      assert [_album_id] = payload.albums
      assert [_artist_id] = payload.artists
    end
  end

  describe "analyzer" do
    test "can scan mp3 file without tags" do
      expect_probe(fn _path ->
        {:ok, %{format: %{duration: "3.448125"}}}
      end)

      path = Path.join(@fixtures_path, "without_tags/sample.mp3")
      assert {:ok, result} = Analyzer.analyze(path)
      assert result.path == path
      assert result.type == :mp3
      assert result.size == 55_170
      assert result.checksum == "1392cce60f3309ed44d089500ae92e77dc5c966a"
      assert result.last_modified_at
      refute result.metadata.artist
      refute result.metadata.album
      refute result.metadata.title
      refute result.metadata.track
      refute result.metadata.release_year
      assert result.metadata.duration == 3.448125
      assert result.metadata.genres == []
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

        assert {:ok, result} = Analyzer.analyze(path)
        assert result.path == path

        assert %{
                 artist: "Test Artist",
                 album: "Test Album",
                 title: "Test Title",
                 track: 3,
                 release_year: 2000,
                 genres: ["Jazz"]
               } = result.metadata
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
        expect_probe(fn ^path -> {:ok, %{}} end)
        assert {:ok, result} = Analyzer.analyze(path)
        assert result.path == path
        assert result.type == type
      end
    end

    test "ignores non-music files" do
      files = [
        Path.join(@fixtures_path, "README.md"),
        Path.join(@fixtures_path, "random.bin")
      ]

      for path <- files do
        assert {:error, :analyzing_failed} = Analyzer.analyze(path)
      end
    end
  end

  describe "walker" do
    test "walks given directory to find all files" do
      walker = Walker.walk(@fixtures_path)

      expected = [
        Path.join(@fixtures_path, "/README.md"),
        Path.join(@fixtures_path, "/with_tags/sample.flac"),
        Path.join(@fixtures_path, "/with_tags/sample.id3v11.mp3"),
        Path.join(@fixtures_path, "/with_tags/sample.id3v22.mp3"),
        Path.join(@fixtures_path, "/with_tags/sample.id3v23.mp3"),
        Path.join(@fixtures_path, "/with_tags/sample.id3v24.mp3"),
        Path.join(@fixtures_path, "/with_tags/sample.m4a"),
        Path.join(@fixtures_path, "/with_tags/sample.multipage.ogg"),
        Path.join(@fixtures_path, "/with_tags/sample.ogg"),
        Path.join(@fixtures_path, "/without_tags/sample.flac"),
        Path.join(@fixtures_path, "/without_tags/sample.m4a"),
        Path.join(@fixtures_path, "/without_tags/sample.mp3"),
        Path.join(@fixtures_path, "/without_tags/sample.ogg"),
        Path.join(@fixtures_path, "/without_tags/sample.opus"),
        Path.join(@fixtures_path, "/without_tags/sample.wav")
      ]

      assert ^expected = Enum.into(walker, [])
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

  defp stub_probe(fun) do
    stub(MusicBox.Tool.ProbeMock, :exec, fn path ->
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
