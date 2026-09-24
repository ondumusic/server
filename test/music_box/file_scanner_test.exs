defmodule MusicBox.FileScannerTest do
  use MusicBox.DataCase, async: false

  setup :set_mox_global
  # setup :verify_on_exit!

  alias MusicBox.FileScanner
  alias MusicBox.FileScanner.Analyzer
  alias MusicBox.FileScanner.Utils
  alias MusicBox.Settings
  alias MusicBox.Storage

  @fixtures_path Path.expand("../support/fixtures/music_files", __DIR__)

  test "cannot start scan if music_path not configured" do
    MusicBox.Repo.delete_all(Settings)
    assert {:error, :missing_music_path} = FileScanner.scan()
  end

  setup do
    Settings.set(%{music_path: @fixtures_path})
    []
  end

  describe "filescanner" do
    setup do
      start_supervised!(FileScanner.Supervisor)

      Phoenix.PubSub.subscribe(MusicBox.PubSub, "library:sync")

      on_exit(fn ->
        Phoenix.PubSub.unsubscribe(MusicBox.PubSub, "library:sync")
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
      Repo.delete_all(MusicBox.Files.File)
      Repo.delete_all(MusicBox.Albums.Album)
      Repo.delete_all(MusicBox.Artists.Artist)
      Repo.delete_all(MusicBox.Tracks.Track)
      Repo.delete_all(MusicBox.DeletionLog)

      assert {:ok, :scan_completed} = FileScanner.scan(:full)
      file_count = Repo.aggregate(MusicBox.Files.File, :count)
      assert_receive %{topic: "library:sync", event: "processed", payload: payload}
      assert_receive %{topic: "library:sync", event: "completed"}
      assert [_album_id] = payload.albums
      assert [_artist_id] = payload.artists

      assert {:ok, :scan_completed} = FileScanner.scan(:quick)
      new_file_count = Repo.aggregate(MusicBox.Files.File, :count)
      assert file_count == new_file_count
      assert_receive %{topic: "library:sync", event: "completed"}
      refute_receive %{topic: "library:sync"}, 200
    end

    test "rescans existing files when doing a full scan" do
      assert {:ok, :scan_completed} = FileScanner.scan(:full)
      file_count = Repo.aggregate(MusicBox.Files.File, :count)
      assert_receive %{topic: "library:sync", event: "processed", payload: payload}
      assert [_album_id] = payload.albums
      assert [_artist_id] = payload.artists

      assert {:ok, :scan_completed} = FileScanner.scan(:full)
      new_file_count = Repo.aggregate(MusicBox.Files.File, :count)
      assert file_count == new_file_count
      assert_receive %{topic: "library:sync", event: "processed", payload: payload}
      assert [_album_id] = payload.albums
      assert [_artist_id] = payload.artists
    end

    test "keeps loudness of unchanged files on a full scan" do
      alias MusicBox.Files.{File, Loudness}

      assert {:ok, :scan_completed} = FileScanner.scan(:full)

      loudness = %Loudness{lufs: -14.0, peak: -1.0, measured_at: DateTime.utc_now(:second)}
      Repo.update_all(File, set: [loudness: loudness])

      # Pretend one file changed on disk since it was measured
      scanned = from(f in File, where: not is_nil(f.last_scanned_at))
      [changed | _] = Repo.all(scanned)
      Repo.update_all(from(f in File, where: f.id == ^changed.id), inc: [size: 1])

      assert {:ok, :scan_completed} = FileScanner.scan(:full)

      for file <- Repo.all(scanned) do
        if file.id == changed.id,
          do: assert(is_nil(file.loudness)),
          else: assert(file.loudness == loudness)
      end
    end

    test "can start async" do
      {:ok, :scan_started} = FileScanner.scan_async(:full)
      assert_receive %{topic: "library:sync", event: "processed", payload: payload}
      assert [_album_id] = payload.albums
      assert [_artist_id] = payload.artists
    end
  end

  describe "analyzer" do
    test "can scan mp3 file without tags" do
      expect_probe(fn _path ->
        {:ok, %{format: %{duration: "3.448125"}}}
      end)

      path = "without_tags/sample.mp3"
      assert {:ok, result} = Analyzer.analyze(file_result(path))
      assert result.path == path
      assert result.type == :mp3
      assert result.size == 123_456
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
        "with_tags/sample.id3v11.mp3",
        "with_tags/sample.m4a",
        "with_tags/sample.flac",
        "with_tags/sample.multipage.ogg",
        "with_tags/sample.id3v22.mp3",
        "with_tags/sample.ogg",
        "with_tags/sample.id3v23.mp3",
        "with_tags/sample.id3v24.mp3"
      ]

      for path <- files do
        abs_path = Path.join(@fixtures_path, path)

        expect_probe(fn "file://" <> ^abs_path ->
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

        assert {:ok, result} = Analyzer.analyze(file_result(path))
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
        {:mp3, "without_tags/sample.mp3"},
        {:m4a, "without_tags/sample.m4a"},
        {:flac, "without_tags/sample.flac"},
        {:ogg, "without_tags/sample.ogg"},
        {:opus, "without_tags/sample.opus"},
        {:wav, "without_tags/sample.wav"},
        {:mp3, "with_tags/sample.id3v11.mp3"},
        {:m4a, "with_tags/sample.m4a"},
        {:flac, "with_tags/sample.flac"},
        {:ogg, "with_tags/sample.multipage.ogg"},
        {:mp3, "with_tags/sample.id3v22.mp3"},
        {:ogg, "with_tags/sample.ogg"},
        {:mp3, "with_tags/sample.id3v23.mp3"},
        {:mp3, "with_tags/sample.id3v24.mp3"}
      ]

      for {type, path} <- files do
        abs_path = Path.join(@fixtures_path, path)
        expect_probe(fn "file://" <> ^abs_path -> {:ok, %{}} end)

        assert {:ok, result} = Analyzer.analyze(file_result(path))

        assert result.path == path
        assert result.type == type
      end
    end

    test "ignores non-music files" do
      files = [
        "README.md",
        "random.bin"
      ]

      for path <- files do
        assert {:error, :analyzing_failed} = Analyzer.analyze(file_result(path))
      end
    end
  end

  describe "file walker" do
    test "walks given directory to find all files" do
      walker = Storage.walk("/")

      expected = [
        "with_tags/sample.aac",
        "with_tags/sample.aiff",
        "with_tags/sample.flac",
        "with_tags/sample.id3v11.mp3",
        "with_tags/sample.id3v22.mp3",
        "with_tags/sample.id3v23.mp3",
        "with_tags/sample.id3v24.mp3",
        "with_tags/sample.m4a",
        "with_tags/sample.multipage.ogg",
        "with_tags/sample.ogg",
        "without_tags/sample.aac",
        "without_tags/sample.aiff",
        "without_tags/sample.flac",
        "without_tags/sample.m4a",
        "without_tags/sample.mp3",
        "without_tags/sample.ogg",
        "without_tags/sample.opus",
        "without_tags/sample.wav"
      ]

      assert ^expected = Enum.into(walker, []) |> Enum.map(& &1.path)
    end
  end

  describe "special test cases" do
    setup do
      Settings.set(%{music_path: @fixtures_path})
      start_supervised!(FileScanner.Supervisor)

      Phoenix.PubSub.subscribe(MusicBox.PubSub, "library:sync")

      on_exit(fn ->
        Phoenix.PubSub.unsubscribe(MusicBox.PubSub, "library:sync")
      end)

      :ok
    end

    test "( ) album should not have duplicates" do
      stub_probe(fn _path ->
        {:ok,
         %{
           format: %{
             duration: "704.1420",
             tags: %{
               artist: "Sigur Rós",
               album: "( )",
               title: "Untitled",
               genre: "Post-rock",
               date: "2002-10-28",
               track: "8"
             }
           }
         }}
      end)

      assert {:ok, :scan_completed} = FileScanner.scan(:full)
      file_count = Repo.aggregate(MusicBox.Files.File, :count)
      album_count = Repo.aggregate(MusicBox.Albums.Album, :count)
      assert album_count == 2

      assert {:ok, :scan_completed} = FileScanner.scan(:full)
      assert file_count == Repo.aggregate(MusicBox.Files.File, :count)
      assert album_count == Repo.aggregate(MusicBox.Albums.Album, :count)

      assert {:ok, :scan_completed} = FileScanner.scan(:full)
      assert file_count == Repo.aggregate(MusicBox.Files.File, :count)
      assert album_count == Repo.aggregate(MusicBox.Albums.Album, :count)
    end

    test "album gets release year even if only one track has it" do
      stub_probe_with_dates(fn
        "file://" <> path -> if String.ends_with?(path, "with_tags/sample.flac"), do: "1999"
      end)

      assert {:ok, :scan_completed} = FileScanner.scan(:full)
      assert %{release_year: 1999} = Repo.get_by!(MusicBox.Albums.Album, slug: "test-album")
    end

    test "album release year is nil when tracks have conflicting years" do
      stub_probe_with_dates(fn
        "file://" <> path ->
          cond do
            String.ends_with?(path, "with_tags/sample.flac") -> "1999"
            String.ends_with?(path, "with_tags/sample.ogg") -> "2001"
            true -> nil
          end
      end)

      assert {:ok, :scan_completed} = FileScanner.scan(:full)
      assert %{release_year: nil} = Repo.get_by!(MusicBox.Albums.Album, slug: "test-album")
    end
  end

  defp stub_probe_with_dates(date_fun) do
    stub_probe(fn path ->
      tags =
        %{artist: "Test Artist", album: "Test Album", title: "Test Title", track: "1"}

      tags =
        case date_fun.(path) do
          nil -> tags
          date -> Map.put(tags, :date, date)
        end

      {:ok, %{format: %{duration: "3.4", tags: tags}}}
    end)
  end

  describe "utils" do
    test "generates sort name" do
      assert "the beatles" == Utils.sort_name("The Beatles")
      assert "beatles" == Utils.sort_name("The Beatles", strip_prefixes: ~w(the))
      assert "the beatles" == Utils.sort_name("The The Beatles", strip_prefixes: ~w(the))
      assert "la beatles" == Utils.sort_name("The La Beatles", strip_prefixes: ~w(the la))
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

  defp file_result(path) do
    %{
      path: path,
      size: 123_456,
      mtime: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end
end
