defmodule MusicBox.SongsTest do
  use MusicBox.DataCase

  alias MusicBox.Songs

  @moduletag :skip
  describe "songs" do
    alias MusicBox.Songs.Song

    import MusicBox.SongsFixtures

    @invalid_attrs %{name: nil, artist_id: nil, album_id: nil, duration: nil}

    test "list_songs/0 returns all songs" do
      song = song_fixture()
      assert Songs.list_songs() == [song]
    end

    test "get_song!/1 returns the song with given id" do
      song = song_fixture()
      assert Songs.get_song!(song.id) == song
    end

    test "create_song/1 with valid data creates a song" do
      valid_attrs = %{
        name: "some name",
        artist_id: "7488a646-e31f-11e4-aace-600308960662",
        album_id: "7488a646-e31f-11e4-aace-600308960662",
        duration: 120.5
      }

      assert {:ok, %Song{} = song} = Songs.create_song(valid_attrs)
      assert song.name == "some name"
      assert song.artist_id == "7488a646-e31f-11e4-aace-600308960662"
      assert song.album_id == "7488a646-e31f-11e4-aace-600308960662"
      assert song.duration == 120.5
    end

    test "create_song/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Songs.create_song(@invalid_attrs)
    end

    test "update_song/2 with valid data updates the song" do
      song = song_fixture()

      update_attrs = %{
        name: "some updated name",
        artist_id: "7488a646-e31f-11e4-aace-600308960668",
        album_id: "7488a646-e31f-11e4-aace-600308960668",
        duration: 456.7
      }

      assert {:ok, %Song{} = song} = Songs.update_song(song, update_attrs)
      assert song.name == "some updated name"
      assert song.artist_id == "7488a646-e31f-11e4-aace-600308960668"
      assert song.album_id == "7488a646-e31f-11e4-aace-600308960668"
      assert song.duration == 456.7
    end

    test "update_song/2 with invalid data returns error changeset" do
      song = song_fixture()
      assert {:error, %Ecto.Changeset{}} = Songs.update_song(song, @invalid_attrs)
      assert song == Songs.get_song!(song.id)
    end

    test "delete_song/1 deletes the song" do
      song = song_fixture()
      assert {:ok, %Song{}} = Songs.delete_song(song)
      assert_raise Ecto.NoResultsError, fn -> Songs.get_song!(song.id) end
    end

    test "change_song/1 returns a song changeset" do
      song = song_fixture()
      assert %Ecto.Changeset{} = Songs.change_song(song)
    end
  end
end
