defmodule Ondu.FileScanner.PlannerTest do
  use Ondu.DataCase, async: true

  import Ondu.FileFixtures

  alias Ondu.Albums.Album
  alias Ondu.Artists.Artist
  alias Ondu.FileScanner.{Plan, Planner}

  test "does not plan if there are no files missing or found" do
    assert Planner.plan([], []) == %Plan{}
  end

  test "does not move a file that still exists" do
    # The old file still exists so the new one is a copy.
    insert_file("Old/01 Song.flac", 100)
    deferred = [scanned_file("New/01 Song.flac", 100)]

    assert %Plan{
             moved_files: [],
             replaced_files: [],
             deleted_files: [],
             saved_files: ^deferred
           } = Planner.plan(deferred, [])
  end

  test "moves a missing file to its new path" do
    file = insert_file("Old/01 Song.flac", 100)
    deferred = [scanned_file("New/01 Song.flac", 100)]

    assert %Plan{
             moved_files: [move],
             replaced_files: [],
             deleted_files: [],
             saved_files: ^deferred
           } = Planner.plan(deferred, [file.id])

    assert move == %{file_id: file.id, from: "Old/01 Song.flac", to: "New/01 Song.flac"}
  end

  test "pairs up identical files by path order" do
    one = insert_file("Old/1/01 Song.flac", 100)
    two = insert_file("Old/2/01 Song.flac", 100)

    deferred = [
      scanned_file("New/2/01 Song.flac", 100),
      scanned_file("New/1/01 Song.flac", 100)
    ]

    assert %Plan{
             moved_files: moves,
             deleted_files: [],
             replaced_files: [],
             saved_files: ^deferred
           } = Planner.plan(deferred, [two.id, one.id])

    assert Enum.map(moves, &{&1.file_id, &1.to}) == [
             {one.id, "New/1/01 Song.flac"},
             {two.id, "New/2/01 Song.flac"}
           ]
  end

  test "replaces a missing file with a retagged one" do
    file = insert_file("Album/01 Song.flac", 100)
    deferred = [scanned_file("Album/01 Song (fixed).flac", 120, %{album: "Album (Fixed)"})]

    assert %Plan{
             moved_files: [],
             deleted_files: [],
             replaced_files: [replacement],
             saved_files: ^deferred
           } = Planner.plan(deferred, [file.id])

    assert replacement.file_id == file.id
    assert replacement.to == "Album/01 Song (fixed).flac"
  end

  test "replaces a missing file with a re-encoded one" do
    file = insert_file("Album/01 Song.mp3", 100)
    deferred = [scanned_file("Album/01 Song.flac", 900, %{duration: 201.9})]

    assert %Plan{
             moved_files: [],
             deleted_files: [],
             replaced_files: [%{file_id: file_id}],
             saved_files: ^deferred
           } = Planner.plan(deferred, [file.id])

    assert file_id == file.id
  end

  test "deletes missing files that were not moved or replaced" do
    moved = insert_file("Old/01 Song.flac", 100)
    gone = insert_file("Old/02 Gone.flac", 100, %{title: "Gone", track: 2, duration: 99.0})
    deferred = [scanned_file("New/01 Song.flac", 100)]

    assert %Plan{
             moved_files: [%{file_id: file_id}],
             deleted_files: deletes,
             replaced_files: [],
             saved_files: ^deferred
           } = Planner.plan(deferred, [moved.id, gone.id])

    assert file_id == moved.id
    assert deletes == [gone.id]
  end

  test "does not treat a retagged file as moved or replaced" do
    missing = insert_file("Old/01 Song.flac", 100)
    insert_file("Album/01 Song.flac", 100, %{album: "Before"})

    # The tags of a known file changed, so it is not a new file.
    deferred = [scanned_file("Album/01 Song.flac", 100)]

    assert %Plan{
             moved_files: [],
             replaced_files: [],
             deleted_files: deletes,
             saved_files: ^deferred
           } = Planner.plan(deferred, [missing.id])

    assert deletes == [missing.id]
  end

  describe "renamed albums" do
    @typo %{album_artist: "Artist", album: "Albun"}
    @fixed %{album_artist: "Artist", album: "Album"}
    @one %{title: "One", track: 1, duration: 101.0}
    @two %{title: "Two", track: 2, duration: 102.0}

    defp tags(album, track), do: Map.merge(album, track)

    test "renames the album when all of its files were retagged in place" do
      insert_file("Albun/01 One.flac", 100, tags(@typo, @one))
      insert_file("Albun/02 Two.flac", 100, tags(@typo, @two))
      album = Repo.get_by!(Album, slug: "albun")

      deferred = [
        scanned_file("Albun/01 One.flac", 110, tags(@fixed, @one)),
        scanned_file("Albun/02 Two.flac", 110, tags(@fixed, @two))
      ]

      assert %Plan{renamed_albums: [rename]} = Planner.plan(deferred, [])
      assert rename == %{album_id: album.id, album_artist: "Artist", album: "Album"}
    end

    test "renames the album when all of its files were moved and retagged" do
      one = insert_file("Albun/01 One.flac", 100, tags(@typo, @one))
      two = insert_file("Albun/02 Two.flac", 100, tags(@typo, @two))
      album = Repo.get_by!(Album, slug: "albun")

      deferred = [
        scanned_file("Album/01 One.flac", 110, tags(@fixed, @one)),
        scanned_file("Album/02 Two.flac", 110, tags(@fixed, @two))
      ]

      assert %Plan{replaced_files: [_, _], renamed_albums: [%{album_id: album_id}]} =
               Planner.plan(deferred, [one.id, two.id])

      assert album_id == album.id
    end

    test "renames the album when the rest of its files were deleted" do
      insert_file("Albun/01 One.flac", 100, tags(@typo, @one))
      gone = insert_file("Albun/02 Two.flac", 100, tags(@typo, @two))
      album = Repo.get_by!(Album, slug: "albun")

      deferred = [scanned_file("Albun/01 One.flac", 110, tags(@fixed, @one))]

      assert %Plan{deleted_files: [_], renamed_albums: [%{album_id: album_id}]} =
               Planner.plan(deferred, [gone.id])

      assert album_id == album.id
    end

    test "does not rename the album when its files were only moved" do
      one = insert_file("Old/01 One.flac", 100, tags(@typo, @one))
      deferred = [scanned_file("New/01 One.flac", 100, tags(@typo, @one))]

      assert %Plan{moved_files: [_], renamed_albums: []} = Planner.plan(deferred, [one.id])
    end

    test "does not rename the album when some of its files remain" do
      insert_file("Albun/01 One.flac", 100, tags(@typo, @one))
      insert_file("Albun/02 Two.flac", 100, tags(@typo, @two))

      deferred = [scanned_file("Albun/01 One.flac", 110, tags(@fixed, @one))]

      assert %Plan{renamed_albums: []} = Planner.plan(deferred, [])
    end

    test "does not rename the album when its files were retagged to an existing album" do
      insert_file("Albun/01 One.flac", 100, tags(@typo, @one))
      insert_file("Album/02 Two.flac", 100, tags(@fixed, @two))

      deferred = [scanned_file("Albun/01 One.flac", 110, tags(@fixed, @one))]

      assert %Plan{renamed_albums: []} = Planner.plan(deferred, [])
    end

    test "does not rename the album when its files were split over albums" do
      insert_file("Albun/01 One.flac", 100, tags(@typo, @one))
      insert_file("Albun/02 Two.flac", 100, tags(@typo, @two))

      deferred = [
        scanned_file("Albun/01 One.flac", 110, tags(@fixed, @one)),
        scanned_file("Albun/02 Two.flac", 110, tags(%{@fixed | album: "Other"}, @two))
      ]

      assert %Plan{renamed_albums: []} = Planner.plan(deferred, [])
    end

    test "renames the album when new files were added to it" do
      insert_file("Albun/01 One.flac", 100, tags(@typo, @one))
      album = Repo.get_by!(Album, slug: "albun")

      deferred = [
        scanned_file("Albun/01 One.flac", 110, tags(@fixed, @one)),
        scanned_file("Albun/02 Two.flac", 110, tags(@fixed, @two))
      ]

      assert %Plan{renamed_albums: [%{album_id: album_id}]} = Planner.plan(deferred, [])
      assert album_id == album.id
    end

    test "does not rename the album when tracks of another album were retagged to it" do
      insert_file("Albun/01 One.flac", 100, tags(@typo, @one))
      insert_file("Other Album/02 Two.flac", 100, tags(%{@typo | album: "Other Album"}, @two))

      deferred = [
        scanned_file("Albun/01 One.flac", 110, tags(@fixed, @one)),
        scanned_file("Other Album/02 Two.flac", 110, tags(@fixed, @two))
      ]

      assert %Plan{renamed_albums: []} = Planner.plan(deferred, [])
    end
  end

  describe "renamed artists" do
    @typo_artist %{artist: "Artst", album_artist: "Artst"}
    @fixed_artist %{artist: "Artist", album_artist: "Artist"}
    @first_track %{album: "First Album", title: "One", track: 1, duration: 101.0}
    @second_track %{album: "Second Album", title: "Two", track: 1, duration: 102.0}

    test "renames the artist when all of its albums were renamed" do
      insert_file("First Album/01 One.flac", 100, tags(@typo_artist, @first_track))
      insert_file("Second Album/01 Two.flac", 100, tags(@typo_artist, @second_track))
      artist = Repo.get_by!(Artist, slug: "artst")

      deferred = [
        scanned_file("First Album/01 One.flac", 110, tags(@fixed_artist, @first_track)),
        scanned_file("Second Album/01 Two.flac", 110, tags(@fixed_artist, @second_track))
      ]

      assert %Plan{renamed_albums: [_, _], renamed_artists: [rename]} =
               Planner.plan(deferred, [])

      assert rename == %{artist_id: artist.id, artist: "Artist"}
    end

    test "renames the artist when new files were added with the new name" do
      insert_file("First Album/01 One.flac", 100, tags(@typo_artist, @first_track))
      artist = Repo.get_by!(Artist, slug: "artst")

      deferred = [
        scanned_file("First Album/01 One.flac", 110, tags(@fixed_artist, @first_track)),
        scanned_file("Second Album/01 Two.flac", 110, tags(@fixed_artist, @second_track))
      ]

      assert %Plan{renamed_artists: [%{artist_id: artist_id}]} = Planner.plan(deferred, [])
      assert artist_id == artist.id
    end

    test "does not rename the artist when tracks of another artist were retagged to it" do
      insert_file("First Album/01 One.flac", 100, tags(@typo_artist, @first_track))

      insert_file(
        "Second Album/01 Two.flac",
        100,
        tags(%{@fixed_artist | artist: "Other", album_artist: "Other"}, @second_track)
      )

      deferred = [
        scanned_file("First Album/01 One.flac", 110, tags(@fixed_artist, @first_track)),
        scanned_file("Second Album/01 Two.flac", 110, tags(@fixed_artist, @second_track))
      ]

      assert %Plan{renamed_artists: []} = Planner.plan(deferred, [])
    end

    test "does not rename the artist when some of its albums remain" do
      insert_file("First Album/01 One.flac", 100, tags(@typo_artist, @first_track))
      insert_file("Second Album/01 Two.flac", 100, tags(@typo_artist, @second_track))

      deferred = [scanned_file("First Album/01 One.flac", 110, tags(@fixed_artist, @first_track))]

      assert %Plan{renamed_albums: [_], renamed_artists: []} = Planner.plan(deferred, [])
    end

    test "does not rename the artist when its albums were retagged to an existing artist" do
      insert_file("First Album/01 One.flac", 100, tags(@typo_artist, @first_track))
      insert_file("Second Album/01 Two.flac", 100, tags(@fixed_artist, @second_track))

      deferred = [scanned_file("First Album/01 One.flac", 110, tags(@fixed_artist, @first_track))]

      assert %Plan{renamed_albums: [_], renamed_artists: []} = Planner.plan(deferred, [])
    end

    test "does not rename the artist when it is still the artist of other tracks" do
      insert_file("First Album/01 One.flac", 100, tags(@typo_artist, @first_track))

      insert_file(
        "Various/01 Two.flac",
        100,
        tags(%{@typo_artist | album_artist: "Various Artists"}, @second_track)
      )

      deferred = [scanned_file("First Album/01 One.flac", 110, tags(@fixed_artist, @first_track))]

      assert %Plan{renamed_albums: [_], renamed_artists: []} = Planner.plan(deferred, [])
    end

    test "does not rename the artist when only the album artist changed" do
      insert_file("First Album/01 One.flac", 100, tags(@typo_artist, @first_track))

      # Only the album artist was changed, the track artist stays the same.
      tags = tags(%{@fixed_artist | artist: "Artst"}, @first_track)
      deferred = [scanned_file("First Album/01 One.flac", 110, tags)]

      assert %Plan{renamed_albums: [_], renamed_artists: []} = Planner.plan(deferred, [])
    end
  end
end
