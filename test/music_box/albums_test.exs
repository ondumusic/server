defmodule MusicBox.AlbumsTest do
  use MusicBox.DataCase

  alias MusicBox.Albums

  @moduletag :skip
  describe "albums" do
    alias MusicBox.Albums.Album

    import MusicBox.AlbumsFixtures

    @invalid_attrs %{name: nil, artist_id: nil, release_year: nil}

    test "list_albums/0 returns all albums" do
      album = album_fixture()
      assert Albums.list_albums() == [album]
    end

    test "get_album!/1 returns the album with given id" do
      album = album_fixture()
      assert Albums.get_album!(album.id) == album
    end

    test "create_album/1 with valid data creates a album" do
      valid_attrs = %{
        name: "some name",
        artist_id: "7488a646-e31f-11e4-aace-600308960662",
        release_year: 42
      }

      assert {:ok, %Album{} = album} = Albums.create_album(valid_attrs)
      assert album.name == "some name"
      assert album.artist_id == "7488a646-e31f-11e4-aace-600308960662"
      assert album.release_year == 42
    end

    test "create_album/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Albums.create_album(@invalid_attrs)
    end

    test "update_album/2 with valid data updates the album" do
      album = album_fixture()

      update_attrs = %{
        name: "some updated name",
        artist_id: "7488a646-e31f-11e4-aace-600308960668",
        release_year: 43
      }

      assert {:ok, %Album{} = album} = Albums.update_album(album, update_attrs)
      assert album.name == "some updated name"
      assert album.artist_id == "7488a646-e31f-11e4-aace-600308960668"
      assert album.release_year == 43
    end

    test "update_album/2 with invalid data returns error changeset" do
      album = album_fixture()
      assert {:error, %Ecto.Changeset{}} = Albums.update_album(album, @invalid_attrs)
      assert album == Albums.get_album!(album.id)
    end

    test "delete_album/1 deletes the album" do
      album = album_fixture()
      assert {:ok, %Album{}} = Albums.delete_album(album)
      assert_raise Ecto.NoResultsError, fn -> Albums.get_album!(album.id) end
    end

    test "change_album/1 returns a album changeset" do
      album = album_fixture()
      assert %Ecto.Changeset{} = Albums.change_album(album)
    end
  end
end
