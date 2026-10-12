defmodule Ondu.IssuesTest do
  use Ondu.DataCase, async: true

  alias Ondu.Albums
  alias Ondu.Albums.Album
  alias Ondu.Issues

  describe "list/1" do
    test "returns nothing for a clean library" do
      assert %{entries: [], total_entries: 0, total_pages: 0, page_number: 1} = Issues.list()
    end

    test "finds album issues" do
      artist = TestSeeds.insert_artist(%{name: "Issues Artist"})

      album =
        TestSeeds.insert_album(artist, %{
          name: "Broken Album",
          release_year: nil,
          tracks: [
            %{track: 1, name: "One"},
            %{track: 1, name: "Also One"},
            %{track: 4, name: "Four", title: nil},
            %{track: nil, name: "No Number"},
            %{track: 2, disc: 2, name: "Disc Two"}
          ]
        })

      set_artwork(album, %{hash: "4f1c2a9d8e7b6c5a", width: 250, height: 200})

      assert %{entries: [entry], total_entries: 1} = Issues.list()
      assert entry.type == :album
      assert entry.album.id == album.id
      assert entry.album.artist.id == artist.id

      track_id = fn name -> Repo.get_by!(Ondu.Tracks.Track, name: name).id end

      assert entry.issues == [
               %{code: :artwork_not_square, details: %{width: 250, height: 200}},
               %{code: :artwork_low_res, details: %{width: 250, height: 200}},
               %{code: :release_year_missing, details: %{}},
               %{code: :track_number_missing, details: %{track_ids: [track_id.("No Number")]}},
               %{code: :track_number_duplicate, details: %{disc: 1, numbers: [1]}},
               %{code: :track_number_gap, details: %{disc: 1, numbers: [2, 3]}},
               %{code: :track_number_gap, details: %{disc: 2, numbers: [1]}},
               %{code: :title_missing, details: %{track_ids: [track_id.("Four")]}}
             ]
    end

    test "only reports missing artwork once the fetchers ran" do
      [album] = Repo.all(Album)
      assert %{entries: []} = Issues.list()

      set_artwork(album, %{fetcher: :embedded})

      assert %{entries: [%{issues: [%{code: :artwork_missing}]}]} = Issues.list()
    end

    test "finds tracks that are orphaned first" do
      TestSeeds.insert_track(nil, nil, %{name: "01 Untagged.m4a", title: nil})

      TestSeeds.insert_album(Repo.one!(Ondu.Artists.Artist), %{
        name: "No Year",
        release_year: nil
      })

      assert %{entries: [track_entry, album_entry]} = Issues.list()

      assert %{type: :track, track: track, issues: issues} = track_entry
      assert track.name == "01 Untagged.m4a"
      assert track.file.path =~ "01 Untagged.m4a"

      assert issues == [
               %{code: :title_missing, details: %{}},
               %{code: :artist_missing, details: %{}}
             ]

      assert album_entry.type == :album
    end

    test "filters by code" do
      artist = Repo.one!(Ondu.Artists.Artist)
      TestSeeds.insert_album(artist, %{name: "No Year", release_year: nil})
      TestSeeds.insert_track(nil, nil, %{name: "Untagged"})

      assert %{entries: [%{type: :album}]} = Issues.list(%{"code" => "release_year_missing"})
      assert %{entries: [%{type: :track}]} = Issues.list(%{"code" => "artist_missing"})
    end

    test "paginates entries" do
      artist = Repo.one!(Ondu.Artists.Artist)

      for i <- 1..55 do
        TestSeeds.insert_album(artist, %{
          name: "No Year #{String.pad_leading("#{i}", 2, "0")}",
          release_year: nil
        })
      end

      assert %{entries: entries, total_entries: 55, total_pages: 2, page_size: 50} =
               Issues.list()

      assert length(entries) == 50
      assert hd(entries).album.name == "No Year 01"

      assert %{entries: [_ | _] = entries, page_number: 2} = Issues.list(%{"page" => "2"})
      assert Enum.map(entries, & &1.album.name) == Enum.map(51..55, &"No Year #{&1}")
    end
  end

  defp set_artwork(album, attrs) do
    {:ok, _artwork} =
      Albums.update_artwork(
        album,
        Map.merge(%{fetcher: :embedded, last_fetch_attempt: DateTime.utc_now()}, attrs)
      )
  end
end
