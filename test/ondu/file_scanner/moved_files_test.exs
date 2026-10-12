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

  defp track_of(path) do
    Repo.one!(from(t in Track, join: f in assoc(t, :file), where: f.path == ^path))
  end

  test "keeps a moved file and everything linked to its track", %{music_path: music_path} do
    write(music_path, "Old/song.mp3")
    assert {:ok, :scan_completed} = FileScanner.scan(:full)
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
    assert {:ok, :scan_completed} = FileScanner.scan(:quick)

    moved = track_of("New/song.mp3")
    assert moved.id == track.id
    assert moved.file_id == track.file_id

    assert DateTime.after?(moved.updated_at, track.updated_at)

    assert Repo.aggregate(MediaFile, :count) == 1
    assert Repo.exists?(from(i in PlaylistItem, where: i.track_id == ^track.id))
    assert %DateTime{} = Repo.get!(Artwork, track.album_id).invalidated_at
  end

  test "does not keep a file that was moved and retagged", %{music_path: music_path} do
    write(music_path, "Old/song.mp3")
    assert {:ok, :scan_completed} = FileScanner.scan(:full)
    track = track_of("Old/song.mp3")

    move(music_path, "Old/song.mp3", "New/retagged-song.mp3")
    assert {:ok, :scan_completed} = FileScanner.scan(:full)

    refute Repo.get(Track, track.id)
    assert track_of("New/retagged-song.mp3").id != track.id
  end

  test "pairs up copies of the same file", %{music_path: music_path} do
    for path <- ["A/song.mp3", "B/song.mp3", "C/song.mp3"], do: write(music_path, path)
    write(music_path, "C/other.mp3", 10)
    assert {:ok, :scan_completed} = FileScanner.scan(:full)
    tracks = Enum.map(["A/song.mp3", "B/song.mp3"], &track_of/1)

    # Two of the three copies moved, the third stayed.
    move(music_path, "A/song.mp3", "D/song.mp3")
    move(music_path, "B/song.mp3", "E/song.mp3")
    assert {:ok, :scan_completed} = FileScanner.scan(:full)

    moved_ids = Enum.map(["D/song.mp3", "E/song.mp3"], &track_of(&1).id)
    assert Enum.sort(moved_ids) == Enum.sort(Enum.map(tracks, & &1.id))
    assert Repo.aggregate(MediaFile, :count) == 4
  end
end
