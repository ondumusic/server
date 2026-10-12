defmodule Ondu.CountersTest do
  use Ondu.DataCase, async: true

  alias Ondu.Albums.Album
  alias Ondu.Artists.Artist
  alias Ondu.Counters
  alias Ondu.Tracks.Track

  test "updates the counter of the given parents and returns the changed ids" do
    album = Repo.get_by!(Album, slug: "with-the-beatles")

    artist = Repo.get!(Artist, album.artist_id)
    other = TestSeeds.insert_album(artist, %{name: "Other", release_year: nil})

    tracks = Repo.aggregate(where(Track, album_id: ^album.id), :count)
    Repo.update_all(Album, set: [track_count: nil])

    assert [album.id] == Counters.update(Album, :track_count, Track, :album_id, [album.id])
    assert Repo.reload!(album).track_count == tracks
    assert Repo.reload!(other).track_count == nil

    # Unchanged counts are left alone.
    assert [other.id] == Counters.update(Album, :track_count, Track, :album_id)
    assert Repo.reload!(other).track_count == 0
    assert [] == Counters.update(Album, :track_count, Track, :album_id)
  end
end
