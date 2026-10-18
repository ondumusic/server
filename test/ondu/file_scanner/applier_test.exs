defmodule Ondu.FileScanner.ApplierTest do
  use Ondu.DataCase, async: true

  import Ondu.FileFixtures

  alias Ondu.Albums.Album
  alias Ondu.Artists.Artist
  alias Ondu.Files.File
  alias Ondu.FileScanner.{Applier, Plan}
  alias Ondu.Tracks.Track

  test "does nothing for an empty plan" do
    assert Applier.apply(%Plan{}) == :ok
  end

  test "saves new files" do
    saved = scanned_file("Album/01 Song.flac", 100)

    assert :ok = Applier.apply(%Plan{saved_files: [saved]})

    file = Repo.get_by!(File, path: "Album/01 Song.flac") |> Repo.preload(track: :album)
    assert file.track.name == "Song"
    assert file.track.album.name == "Album"
  end

  test "keeps the file and track of a moved file" do
    file = insert_file("Old/01 Song.flac", 100)
    track = Repo.get_by!(Track, file_id: file.id)
    saved = scanned_file("New/01 Song.flac", 100)

    plan = %Plan{
      moved_files: [%{file_id: file.id, from: "Old/01 Song.flac", to: "New/01 Song.flac"}],
      saved_files: [saved]
    }

    assert :ok = Applier.apply(plan)

    moved = Repo.get!(File, file.id)
    assert moved.path == "New/01 Song.flac"
    refute Repo.get_by(File, path: "Old/01 Song.flac")
    assert moved.last_modified_at == saved.last_modified_at
    assert is_nil(moved.content_changed_at)
    assert Repo.get_by!(Track, file_id: file.id).id == track.id
  end

  test "keeps the file and track of a replaced file and saves its new tags" do
    file = insert_file("Album/01 Song.mp3", 100)
    track = Repo.get_by!(Track, file_id: file.id)
    saved = scanned_file("Album/01 Song.flac", 900, %{title: "Song (Fixed)"})

    plan = %Plan{
      replaced_files: [%{file_id: file.id, from: "Album/01 Song.mp3", to: "Album/01 Song.flac"}],
      saved_files: [saved]
    }

    assert :ok = Applier.apply(plan)

    replaced = Repo.get!(File, file.id)
    assert replaced.path == "Album/01 Song.flac"
    refute Repo.get_by(File, path: "Album/01 Song.mp3")
    assert replaced.size == 900
    assert replaced.content_changed_at

    replaced_track = Repo.get_by!(Track, file_id: file.id)
    assert replaced_track.id == track.id
    assert replaced_track.name == "Song (Fixed)"
  end

  test "deletes files" do
    kept = insert_file("Album/01 Song.flac", 100)
    deleted = insert_file("Album/02 Gone.flac", 100, %{title: "Gone", track: 2})

    assert :ok = Applier.apply(%Plan{deleted_files: [deleted.id]})

    assert Repo.get(File, kept.id)
    refute Repo.get(File, deleted.id)
  end

  describe "renamed albums" do
    test "keeps the album" do
      file = insert_file("Albun/01 Song.flac", 100, %{album: "Albun"})
      album = Repo.get_by!(Album, slug: "albun")
      saved = scanned_file("Albun/01 Song.flac", 120)

      plan = %Plan{
        renamed_albums: [%{album_id: album.id, album_artist: "Artist", album: "Album"}],
        saved_files: [saved]
      }

      assert :ok = Applier.apply(plan)

      renamed = Repo.get!(Album, album.id)
      assert renamed.name == "Album"
      assert renamed.slug == "album"
      assert Repo.get_by!(Track, file_id: file.id).album_id == album.id
      refute Repo.get_by(Album, slug: "albun")
    end

    test "keeps the album when its artist changed to an existing one" do
      insert_file("Other/01 Other.flac", 100, %{album_artist: "Other Artist", album: "Other"})
      insert_file("Album/01 Song.flac", 100)
      album = Repo.get_by!(Album, slug: "album")
      other_artist = Repo.get_by!(Artist, slug: "other-artist")
      saved = scanned_file("Album/01 Song.flac", 120, %{album_artist: "Other Artist"})

      plan = %Plan{
        renamed_albums: [%{album_id: album.id, album_artist: "Other Artist", album: "Album"}],
        saved_files: [saved]
      }

      assert :ok = Applier.apply(plan)

      assert Repo.get!(Album, album.id).artist_id == other_artist.id
      assert [_album] = Repo.all(from al in Album, where: al.slug == "album")
    end

    test "keeps the album when its artist changed to a new one" do
      insert_file("Album/01 Song.flac", 100)
      album = Repo.get_by!(Album, slug: "album")
      saved = scanned_file("Album/01 Song.flac", 120, %{album_artist: "New Artist"})

      plan = %Plan{
        renamed_albums: [%{album_id: album.id, album_artist: "New Artist", album: "Album"}],
        saved_files: [saved]
      }

      assert :ok = Applier.apply(plan)

      new_artist = Repo.get_by!(Artist, slug: "new-artist")
      assert Repo.get!(Album, album.id).artist_id == new_artist.id
      assert [_album] = Repo.all(from al in Album, where: al.slug == "album")
    end
  end

  describe "renamed artists" do
    test "keeps the artist and its album" do
      file = insert_file("Album/01 Song.flac", 100, %{artist: "Artst", album_artist: "Artst"})
      artist = Repo.get_by!(Artist, slug: "artst")
      album = Repo.get_by!(Album, slug: "album")
      saved = scanned_file("Album/01 Song.flac", 120)

      plan = %Plan{
        renamed_artists: [%{artist_id: artist.id, artist: "Artist"}],
        renamed_albums: [%{album_id: album.id, album_artist: "Artist", album: "Album"}],
        saved_files: [saved]
      }

      assert :ok = Applier.apply(plan)

      renamed = Repo.get!(Artist, artist.id)
      assert renamed.name == "Artist"
      assert renamed.slug == "artist"
      refute Repo.get_by(Artist, slug: "artst")

      assert Repo.get!(Album, album.id).artist_id == artist.id
      assert [_album] = Repo.all(from al in Album, where: al.slug == "album")

      track = Repo.get_by!(Track, file_id: file.id)
      assert track.artist_id == artist.id
      assert track.album_id == album.id
    end
  end
end
