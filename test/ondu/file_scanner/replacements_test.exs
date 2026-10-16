defmodule Ondu.FileScanner.ReplacementsTest do
  use ExUnit.Case, async: true

  alias Ondu.FileScanner.Replacements
  alias Ondu.FileScanner.Replacements.Candidate

  @song %Candidate{
    path: "Artist/Album/01 Song.mp3",
    duration: 201.512,
    artist: "Artist",
    album: "Album",
    title: "Song",
    disc: 1,
    track: 1
  }

  describe "retagged?/2" do
    test "matches the same audio when the title or album is the same" do
      assert Replacements.retagged?(@song, %{@song | artist: "Other"})
      assert Replacements.retagged?(@song, %{@song | album: "Other", track: 2})
      assert Replacements.retagged?(@song, %{@song | title: "Other", disc: 2})
    end

    test "ignores differences in capitalization, punctuation and accents" do
      fixed = %{@song | album: "Dont stop me now", title: "Beyonce"}

      assert Replacements.retagged?(fixed, %{fixed | album: "Don't Stop Me Now", title: "Beyoncé"})

      symbols = %{@song | album: "...", title: "..."}
      refute Replacements.retagged?(symbols, symbols)
    end

    test "does not match different audio or when the title and album changed" do
      refute Replacements.retagged?(@song, %{@song | duration: 201.513})
      refute Replacements.retagged?(@song, %{@song | album: "Other", title: "Other"})
    end

    test "does not match files without tags" do
      untagged = %{@song | album: nil, title: nil}
      refute Replacements.retagged?(untagged, untagged)
    end
  end

  describe "reencoded?/2" do
    test "matches the same tags with duration of max 1s difference" do
      assert Replacements.reencoded?(@song, %{@song | duration: 201.48})
      assert Replacements.reencoded?(@song, %{@song | duration: 202.5})
    end

    test "does not match a different duration or different tags" do
      refute Replacements.reencoded?(@song, %{@song | duration: 203.0})

      for changes <- [artist: "Other", album: "Other", title: "Other", disc: 2, track: 2],
          do: refute(Replacements.reencoded?(@song, struct!(@song, [changes])))
    end

    test "does not match files without tags" do
      for field <- [:artist, :album, :title] do
        untagged = Map.put(@song, field, nil)
        refute Replacements.reencoded?(untagged, untagged)
      end
    end
  end

  describe "match/2" do
    test "pairs each missing file with the file that replaced it" do
      one = %{@song | path: "Old/1.mp3", title: "One", duration: 180.0}
      two = %{@song | path: "Old/2.mp3", title: "Two", duration: 240.0}
      new_one = %{one | path: "New/1.mp3", album: "New"}
      new_two = %{two | path: "New/2.flac", duration: 240.3}

      assert Replacements.match([one, two], [new_two, new_one]) == [
               {one, new_one},
               {two, new_two}
             ]
    end

    test "does not pair files when there are multiple matches" do
      copy = %{@song | path: "Copy/01 Song.mp3"}
      new = %{@song | path: "New/01 Song.flac", duration: 201.4}

      # Two missing files match the new file, and the other way around
      # so there is no way to know the correct solution here.
      assert Replacements.match([@song, copy], [new]) == []
      assert Replacements.match([@song], [new, %{new | path: "Other/01 Song.flac"}]) == []
    end
  end
end
