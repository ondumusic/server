defmodule Ondu.Issues.RulesTest do
  use ExUnit.Case, async: true

  alias Ondu.Issues.Rules

  @album %{
    id: "album-id",
    release_year: 2000,
    is_unknown: false,
    artwork_hash: "4f1c2a9d8e7b6c5a",
    artwork_fetcher: :embedded,
    artwork_width: 600,
    artwork_height: 600
  }

  describe "album/1" do
    test "returns nothing for a complete album" do
      assert Rules.album(@album) == []
    end

    test "finds missing release year and unknown albums" do
      assert codes(Rules.album(%{@album | release_year: nil})) == [:release_year_missing]
      assert codes(Rules.album(%{@album | is_unknown: true})) == [:album_missing]
    end

    test "only reports missing artwork once the fetchers ran" do
      album = %{@album | artwork_hash: nil, artwork_width: nil, artwork_height: nil}

      assert Rules.album(%{album | artwork_fetcher: nil}) == []
      assert codes(Rules.album(%{album | artwork_fetcher: :embedded})) == [:artwork_missing]
    end

    test "finds non-square and low resolution artwork" do
      assert Rules.album(%{@album | artwork_width: 640, artwork_height: 571}) == [
               %{code: :artwork_not_square, details: %{width: 640, height: 571}}
             ]

      assert Rules.album(%{@album | artwork_width: 300, artwork_height: 250}) == [
               %{code: :artwork_not_square, details: %{width: 300, height: 250}},
               %{code: :artwork_low_res, details: %{width: 300, height: 250}}
             ]
    end
  end

  describe "track_numbers/1" do
    test "returns nothing for complete numbering" do
      assert Rules.track_numbers(tracks(1, [1, 2, 3])) == []
    end

    test "finds tracks without a number" do
      assert Rules.track_numbers([
               %{id: "a", disc: 1, number: 1},
               %{id: "b", disc: 1, number: nil}
             ]) == [%{code: :track_number_missing, details: %{track_ids: ["b"]}}]
    end

    test "finds duplicates and gaps per disc" do
      assert Rules.track_numbers(tracks(1, [1, 1, 4]) ++ tracks(2, [2])) == [
               %{code: :track_number_duplicate, details: %{disc: 1, numbers: [1]}},
               %{code: :track_number_gap, details: %{disc: 1, numbers: [2, 3]}},
               %{code: :track_number_gap, details: %{disc: 2, numbers: [1]}}
             ]
    end
  end

  describe "untitled_tracks/1" do
    test "lists the tracks without a title" do
      assert Rules.untitled_tracks([]) == []

      assert Rules.untitled_tracks(["a", "b"]) == [
               %{code: :title_missing, details: %{track_ids: ["a", "b"]}}
             ]
    end
  end

  describe "orphaned_track/1" do
    test "finds tracks without an artist or album" do
      track = %{id: "t", artist_id: "artist", album_id: "album", title_missing: false}

      assert Rules.orphaned_track(track) == []
      assert codes(Rules.orphaned_track(%{track | album_id: nil})) == [:album_missing]

      assert codes(Rules.orphaned_track(%{track | artist_id: nil, title_missing: true})) ==
               [:artist_missing, :title_missing]
    end
  end

  defp codes(issues), do: Enum.map(issues, & &1.code)

  defp tracks(disc, numbers) do
    for number <- numbers, do: %{id: "#{disc}-#{number}", disc: disc, number: number}
  end
end
