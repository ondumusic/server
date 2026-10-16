defmodule Ondu.FileScanner.MovedFilesTest do
  use Ondu.DataCase, async: false

  setup :set_mox_global

  alias Ondu.Albums.{Album, Artwork}
  alias Ondu.Files.File, as: MediaFile
  alias Ondu.FileScanner
  alias Ondu.Playlists.PlaylistItem
  alias Ondu.Settings
  alias Ondu.Tracks.Track

  @fixture Path.expand("../../support/fixtures/music_files/without_tags/sample.mp3", __DIR__)

  setup do
    music_path = Path.absname("./tmp/test/moved_files")
    File.rm_rf!(music_path)
    File.mkdir_p!(music_path)
    Settings.set(%{music_path: music_path})
    start_supervised!(FileScanner.Supervisor)

    # Only the files of these tests.
    Repo.delete_all(MediaFile)

    # Tags depend on the file name, except for the folder it is in.
    stub(Ondu.Tool.ProbeMock, :exec, fn path ->
      title = path |> Path.basename(".mp3") |> String.replace_prefix("retagged-", "Retagged ")
      tags = %{"artist" => "Artist", "album" => "Album", "title" => title, "track" => "1"}
      {:ok, %{"format" => %{"duration" => "3.4", "tags" => tags}}}
    end)

    [music_path: music_path]
  end

  # Files with the same tags (name) and size are the same file.
  defp write(music_path, path, padding \\ 0) do
    path = Path.join(music_path, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, File.read!(@fixture) <> :binary.copy(<<0>>, padding))
  end

  defp move(music_path, from, to) do
    File.mkdir_p!(Path.dirname(Path.join(music_path, to)))
    File.rename!(Path.join(music_path, from), Path.join(music_path, to))
  end

  # Simulate for example artist or album name change, which could also
  # result in a move. So in this case it will do a "move" by removing the
  # `from` file, and writing to the `to` file with extra padding to make its
  # size different and simulate new tags.
  defp retag(music_path, from, to) do
    File.rm!(Path.join(music_path, from))
    write(music_path, to, 100)
  end

  # Simulate replacing a file with a better version of it, for example an mp3
  # replace with a flac. The file will be different but the tags are the same.
  defp upgrade(music_path, from, to) do
    File.rm!(Path.join(music_path, from))
    write(music_path, to, 1000)
  end

  # Stubs the tags and duration of each file, by its path in the music path.
  defp stub_files(music_path, files) do
    stub(Ondu.Tool.ProbeMock, :exec, fn path ->
      path = path |> String.replace_prefix("file://", "") |> Path.relative_to(music_path)
      {duration, tags} = files |> Map.fetch!(path) |> Map.pop!(:duration)
      tags = Map.new(tags, fn {key, value} -> {to_string(key), to_string(value)} end)
      {:ok, %{"format" => %{"duration" => to_string(duration), "tags" => tags}}}
    end)
  end

  defp scan!(type \\ :full) do
    assert {:ok, :scan_completed} = FileScanner.scan(type)
  end

  # This adds some simulated history to a path by making sure it's part of a
  # playlist and has play history. Then we can ensure this data is preserved
  # after a successfully detected file move/rename.
  defp track_with_history(path) do
    track = track_of(path)
    playlist = TestSeeds.insert_playlist(%{name: "Playlist"})
    TestSeeds.insert_playlist_item(playlist, %{position: "a0", track_id: track.id})
    update_record(track, %{play_count: 3, inserted_at: ~U[2026-01-01 00:00:00Z]})
  end

  # This ensures a given track has not been reinserted after a file move/rename.
  defp assert_kept(track, path) do
    kept = track_of(path)
    assert kept.id == track.id
    assert kept.file_id == track.file_id
    assert kept.play_count == 3
    assert kept.inserted_at == track.inserted_at
    assert Repo.exists?(from(i in PlaylistItem, where: i.track_id == ^track.id))
  end

  defp track_of(path) do
    Repo.one!(from(t in Track, join: f in assoc(t, :file), where: f.path == ^path))
  end

  test "keeps a moved file and everything linked to its track", %{music_path: music_path} do
    write(music_path, "Old/song.mp3")
    scan!()
    track = track_of("Old/song.mp3")

    playlist = TestSeeds.insert_playlist(%{name: "Playlist"})
    TestSeeds.insert_playlist_item(playlist, %{position: "a0", track_id: track.id})
    album = Repo.get!(Album, track.album_id)

    {:ok, _artwork} =
      Ondu.Albums.update_artwork(album, %{
        hash: "hash",
        fetcher: :embedded,
        last_fetch_attempt: ~U[2026-01-01 00:00:00Z]
      })

    track = update_record(track, %{updated_at: ~U[2026-01-01 00:00:00Z]})

    move(music_path, "Old/song.mp3", "New/song.mp3")
    scan!(:quick)

    moved = track_of("New/song.mp3")
    assert moved.id == track.id
    assert moved.file_id == track.file_id

    assert DateTime.after?(moved.updated_at, track.updated_at)

    assert Repo.aggregate(MediaFile, :count) == 1
    assert Repo.exists?(from(i in PlaylistItem, where: i.track_id == ^track.id))
    assert %DateTime{} = Repo.get!(Artwork, track.album_id).invalidated_at
  end

  test "pairs up copies of the same file", %{music_path: music_path} do
    for path <- ["A/song.mp3", "B/song.mp3", "C/song.mp3"], do: write(music_path, path)
    write(music_path, "C/other.mp3", 10)
    scan!(:full)
    tracks = Enum.map(["A/song.mp3", "B/song.mp3"], &track_of/1)

    # Two of the three copies moved, the third stayed.
    move(music_path, "A/song.mp3", "D/song.mp3")
    move(music_path, "B/song.mp3", "E/song.mp3")
    scan!(:full)

    moved_ids = Enum.map(["D/song.mp3", "E/song.mp3"], &track_of(&1).id)
    assert Enum.sort(moved_ids) == Enum.sort(Enum.map(tracks, & &1.id))
    assert Repo.aggregate(MediaFile, :count) == 4
  end

  describe "moved and retagged files" do
    test "keeps a file when the album name was modified", %{music_path: music_path} do
      song = %{artist: "Artist", title: "Song", track: 1, duration: 201.512}

      stub_files(music_path, %{
        "Artist/Albm/01 Song.mp3" => Map.put(song, :album, "Albm"),
        "Artist/Album/01 Song.mp3" => Map.put(song, :album, "Album")
      })

      write(music_path, "Artist/Albm/01 Song.mp3")
      scan!()
      track = track_with_history("Artist/Albm/01 Song.mp3")

      retag(music_path, "Artist/Albm/01 Song.mp3", "Artist/Album/01 Song.mp3")
      scan!()

      assert_kept(track, "Artist/Album/01 Song.mp3")
      assert Repo.aggregate(MediaFile, :count) == 1
    end

    test "keeps a file when the artist name was modified", %{music_path: music_path} do
      song = %{album: "Album", title: "Song", track: 1, duration: 201.512}

      stub_files(music_path, %{
        "Artst/Album/01 Song.mp3" => Map.put(song, :artist, "Artst"),
        "Artist/Album/01 Song.mp3" => Map.put(song, :artist, "Artist")
      })

      write(music_path, "Artst/Album/01 Song.mp3")
      scan!()
      track = track_with_history("Artst/Album/01 Song.mp3")

      retag(music_path, "Artst/Album/01 Song.mp3", "Artist/Album/01 Song.mp3")
      scan!()

      assert_kept(track, "Artist/Album/01 Song.mp3")
    end

    test "keeps a file when the title and track number were modified", %{music_path: music_path} do
      stub_files(music_path, %{
        "Album/02 Sogn.mp3" => %{
          artist: "A",
          album: "Album",
          title: "Sogn",
          track: 2,
          duration: 201.512
        },
        "Album/01 Song.mp3" => %{
          artist: "A",
          album: "Album",
          title: "Song",
          track: 1,
          duration: 201.512
        }
      })

      write(music_path, "Album/02 Sogn.mp3")
      scan!()
      track = track_with_history("Album/02 Sogn.mp3")

      retag(music_path, "Album/02 Sogn.mp3", "Album/01 Song.mp3")
      scan!()

      assert_kept(track, "Album/01 Song.mp3")
    end

    test "keeps every file of a renamed album", %{music_path: music_path} do
      songs = [{"01 One.mp3", 180.04}, {"02 Two.mp3", 240.5}, {"03 Three.mp3", 95.333}]

      files =
        for {name, duration} <- songs, album <- ["Albm", "Album"], into: %{} do
          tags = %{artist: "Artist", album: album, title: name, track: 1, duration: duration}
          {"Artist/#{album}/#{name}", tags}
        end

      stub_files(music_path, files)
      for {name, _duration} <- songs, do: write(music_path, "Artist/Albm/#{name}")
      scan!()
      tracks = for {name, _duration} <- songs, do: track_of("Artist/Albm/#{name}")

      for {name, _duration} <- songs,
          do: retag(music_path, "Artist/Albm/#{name}", "Artist/Album/#{name}")

      scan!()

      for {{name, _duration}, track} <- Enum.zip(songs, tracks),
          do: assert(track_of("Artist/Album/#{name}").id == track.id)
    end

    test "does not keep a file with likely different audio", %{music_path: music_path} do
      stub_files(music_path, %{
        "Album/01 Song.mp3" => %{artist: "A", album: "Album", title: "Song", duration: 201.512},
        "Album/01 Other.mp3" => %{artist: "A", album: "Album", title: "Other", duration: 199.0}
      })

      write(music_path, "Album/01 Song.mp3")
      scan!()
      track = track_of("Album/01 Song.mp3")

      retag(music_path, "Album/01 Song.mp3", "Album/01 Other.mp3")
      scan!()

      # Track has been removed, new one inserted
      refute Repo.get(Track, track.id)
    end

    test "does not keep files when it is not obvious which is which", %{music_path: music_path} do
      # Both files have the same title and duration,
      # so each new file matches both missing files.
      tags = %{artist: "A", title: "Song", duration: 201.512}

      stub_files(music_path, %{
        "Old/1.mp3" => Map.merge(tags, %{album: "Old", track: 1}),
        "Old/2.mp3" => Map.merge(tags, %{album: "Old", track: 2}),
        "New/1.mp3" => Map.merge(tags, %{album: "New", track: 1}),
        "New/2.mp3" => Map.merge(tags, %{album: "New", track: 2})
      })

      write(music_path, "Old/1.mp3")
      write(music_path, "Old/2.mp3")
      scan!()
      tracks = Enum.map(["Old/1.mp3", "Old/2.mp3"], &track_of/1)

      retag(music_path, "Old/1.mp3", "New/1.mp3")
      retag(music_path, "Old/2.mp3", "New/2.mp3")
      scan!()

      # Track has been removed, new one inserted
      for track <- tracks, do: refute(Repo.get(Track, track.id))
      assert Enum.map(["New/1.mp3", "New/2.mp3"], &track_of/1)
    end
  end

  describe "upgraded files" do
    test "keeps a file replaced by a better version", %{music_path: music_path} do
      song = %{artist: "Artist", album: "Album", title: "Song", track: 1}

      stub_files(music_path, %{
        "Album/01 Song.mp3" => Map.put(song, :duration, 201.512),
        "Album/01 Song.flac" => Map.put(song, :duration, 201.48)
      })

      write(music_path, "Album/01 Song.mp3")
      scan!()
      track = track_with_history("Album/01 Song.mp3")

      upgrade(music_path, "Album/01 Song.mp3", "Album/01 Song.flac")
      scan!()

      assert_kept(track, "Album/01 Song.flac")
      assert Repo.aggregate(MediaFile, :count) == 1
    end

    test "does not keep a file replaced by a different version", %{music_path: music_path} do
      song = %{artist: "Artist", album: "Album", title: "Song", track: 1}

      stub_files(music_path, %{
        "Album/01 Song.mp3" => Map.put(song, :duration, 201.512),
        "Album/01 Song.flac" => Map.put(song, :duration, 263.0)
      })

      write(music_path, "Album/01 Song.mp3")
      scan!()
      track = track_of("Album/01 Song.mp3")

      upgrade(music_path, "Album/01 Song.mp3", "Album/01 Song.flac")
      scan!()

      # Tracks has been removed, new ones inserted
      refute Repo.get(Track, track.id)
      assert track_of("A/01 Song.flac")
    end

    test "does not keep files when it is ambiguous which was upgraded", %{music_path: music_path} do
      song = %{artist: "Artist", album: "Album", title: "Song", track: 1}

      # The same song twice, of which one copy is replaced and the other removed.
      stub_files(music_path, %{
        "A/01 Song.mp3" => Map.put(song, :duration, 201.512),
        "B/01 Song.mp3" => Map.put(song, :duration, 201.512),
        "A/01 Song.flac" => Map.put(song, :duration, 201.48)
      })

      write(music_path, "A/01 Song.mp3")
      write(music_path, "B/01 Song.mp3", 10)
      scan!()
      tracks = Enum.map(["A/01 Song.mp3", "B/01 Song.mp3"], &track_of/1)

      File.rm!(Path.join(music_path, "B/01 Song.mp3"))
      upgrade(music_path, "A/01 Song.mp3", "A/01 Song.flac")
      scan!()

      # Tracks has been removed, new ones inserted
      for track <- tracks, do: refute(Repo.get(Track, track.id))
      assert track_of("A/01 Song.flac")
    end
  end
end
