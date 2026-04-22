defmodule MusicBoxWeb.PlaylistControllerTest do
  use MusicBoxWeb.ConnCase, async: false

  alias MusicBox.Playlists
  alias MusicBox.Playlists.Playlist

  setup do
    tracks = MusicBox.Tracks.paginate_tracks(%{}).entries

    items =
      tracks
      |> Enum.filter(&(&1.number in [4, 8, 9]))
      |> Enum.zip(["c", "b", "a"])
      |> Enum.map(fn {track, position} ->
        %{
          position: position,
          track_id: track.id
        }
      end)

    playlist =
      TestSeeds.insert_playlist(%{
        name: "Test Playlist",
        items: items
      })

    [playlist: playlist]
  end

  describe "playlists" do
    setup :register_and_log_in_user

    test "returns paginated list of playlists", %{conn: conn} do
      assert %{
               "pageNumber" => 1,
               "totalPages" => 1,
               "totalEntries" => 1,
               "pageSize" => 100,
               "entries" => [
                 %{
                   "trackCount" => 0,
                   "name" => "Test Playlist"
                 }
               ]
             } =
               conn
               |> get(~p"/api/playlists")
               |> json_response(200)
    end

    test "returns playlist details", %{conn: conn, playlist: playlist} do
      assert %{
               "trackCount" => 0,
               "name" => "Test Playlist"
             } =
               conn
               |> get(~p"/api/playlists/#{playlist.id}")
               |> json_response(200)
    end

    test "returns paginated list of playlist items", %{conn: conn, playlist: playlist} do
      assert %{
               "pageNumber" => 1,
               "totalPages" => 1,
               "totalEntries" => 3,
               "pageSize" => 100,
               "entries" => [
                 %{"position" => "a"},
                 %{"position" => "b"},
                 %{"position" => "c"}
               ]
             } =
               conn
               |> get(~p"/api/playlists/#{playlist.id}/items")
               |> json_response(200)
    end

    test "returns playlist items", %{
      conn: conn,
      playlist: playlist
    } do
      item = hd(playlist.items)

      assert %{"position" => "a"} =
               conn
               |> get(~p"/api/playlists/#{playlist.id}/items/#{item.id}")
               |> json_response(200)
    end

    test "creates playlist", %{conn: conn} do
      assert %{"fields" => %{"name" => %{"message" => "can't be blank"}}} =
               conn
               |> post(~p"/api/playlists", %{
                 name: ""
               })
               |> json_response(422)

      assert %{
               "name" => "My Faves"
             } =
               conn
               |> post(~p"/api/playlists", %{
                 name: "My Faves"
               })
               |> json_response(200)
    end

    test "updates playlist", %{conn: conn, playlist: playlist} do
      assert %{
               "name" => "My New Faves"
             } =
               conn
               |> patch(~p"/api/playlists/#{playlist.id}", %{
                 name: "My New Faves"
               })
               |> json_response(200)
    end

    test "deletes playlist", %{conn: conn, playlist: playlist} do
      assert %{
               "name" => "Test Playlist"
             } =
               conn
               |> delete(~p"/api/playlists/#{playlist.id}")
               |> json_response(200)

      assert Repo.aggregate(Playlist, :count) == 0
    end
  end

  describe "playlist items" do
    setup :register_and_log_in_user

    test "can add items to playlist", %{conn: conn, playlist: playlist} do
      track = MusicBox.Tracks.paginate_tracks(%{}).entries |> Enum.find(&(&1.number == 5))
      position = "d"
      track_id = track.id

      assert %{
               "added" => [
                 %{
                   "position" => ^position,
                   "trackId" => ^track_id
                 }
               ],
               "moved" => [],
               "removed" => []
             } =
               conn
               |> patch(~p"/api/playlists/#{playlist.id}/items", %{
                 add: [
                   %{
                     position: position,
                     trackId: track_id
                   }
                 ]
               })
               |> json_response(200)
    end

    test "can move items in playlist", %{conn: conn, playlist: playlist} do
      item = List.first(playlist.items)
      position = "q"
      item_id = item.id

      assert %{
               "added" => [],
               "moved" => [
                 %{
                   "position" => ^position,
                   "id" => ^item_id
                 }
               ],
               "removed" => []
             } =
               conn
               |> patch(~p"/api/playlists/#{playlist.id}/items", %{
                 move: [
                   %{
                     position: position,
                     itemId: item_id
                   }
                 ]
               })
               |> json_response(200)
    end

    test "can remove items from playlist", %{conn: conn, playlist: playlist} do
      item = List.first(playlist.items)
      item_id = item.id

      assert %{
               "added" => [],
               "moved" => [],
               "removed" => [^item_id]
             } =
               conn
               |> patch(~p"/api/playlists/#{playlist.id}/items", %{
                 remove: [item_id]
               })
               |> json_response(200)

      assert %{entries: [_a, _b]} = Playlists.paginate_playlists_items(playlist, %{})
    end

    test "cannot move and remove same item in playlist", %{conn: conn, playlist: playlist} do
      item = List.first(playlist.items)
      position = "q"
      item_id = item.id

      assert %{
               "error" => "move_remove_conflict",
               "itemIds" => [^item_id]
             } =
               conn
               |> patch(~p"/api/playlists/#{playlist.id}/items", %{
                 move: [
                   %{
                     position: position,
                     itemId: item_id
                   }
                 ],
                 remove: [item_id]
               })
               |> json_response(400)
    end

    test "cannot move unknown items", %{conn: conn, playlist: playlist} do
      item_id = Ecto.UUID.generate()

      assert %{
               "error" => "unknown_items",
               "itemIds" => [^item_id]
             } =
               conn
               |> patch(~p"/api/playlists/#{playlist.id}/items", %{
                 move: [
                   %{
                     position: "a",
                     itemId: item_id
                   }
                 ]
               })
               |> json_response(400)
    end

    test "cannot remove unknown items", %{conn: conn, playlist: playlist} do
      item_id = Ecto.UUID.generate()

      assert %{
               "error" => "unknown_items",
               "itemIds" => [^item_id]
             } =
               conn
               |> patch(~p"/api/playlists/#{playlist.id}/items", %{
                 remove: [item_id]
               })
               |> json_response(400)
    end

    test "cannot add unknown tracks", %{conn: conn, playlist: playlist} do
      track_id = Ecto.UUID.generate()

      assert %{
               "error" => "unknown_tracks",
               "trackIds" => [^track_id]
             } =
               conn
               |> patch(~p"/api/playlists/#{playlist.id}/items", %{
                 add: [
                   %{
                     trackId: track_id,
                     position: "a"
                   }
                 ]
               })
               |> json_response(400)
    end

    test "full happy path playlist test", %{conn: conn} do
      artist = MusicBox.Artists.get_artist!("the-beatles")
      album = MusicBox.Albums.get_album_for_artist!(artist, "with-the-beatles")

      [
        track1,
        track2,
        track3,
        track4,
        track5
        | _rest
      ] = album.tracks |> Enum.map(& &1.id)

      assert %{
               "id" => playlist_id,
               "name" => "My Faves"
             } =
               conn
               |> post(~p"/api/playlists", %{
                 name: "My Faves"
               })
               |> json_response(200)

      assert %{
               "added" => [
                 %{
                   "id" => item1,
                   "position" => "a",
                   "trackId" => ^track1
                 },
                 %{
                   "id" => item2,
                   "position" => "b",
                   "trackId" => ^track2
                 },
                 %{
                   "id" => item3,
                   "position" => "c",
                   "trackId" => ^track3
                 },
                 %{
                   "id" => item4,
                   "position" => "d",
                   "trackId" => ^track4
                 }
               ],
               "moved" => [],
               "removed" => []
             } =
               conn
               |> patch(~p"/api/playlists/#{playlist_id}/items", %{
                 add: [
                   %{
                     position: "a",
                     trackId: track1
                   },
                   %{
                     position: "b",
                     trackId: track2
                   },
                   %{
                     position: "c",
                     trackId: track3
                   },
                   %{
                     position: "d",
                     trackId: track4
                   }
                 ]
               })
               |> json_response(200)

      assert %{
               "added" => [
                 %{
                   "position" => "e",
                   "id" => item5,
                   "trackId" => ^track5
                 }
               ],
               "moved" => [
                 %{
                   "position" => "a1",
                   "id" => ^item3
                 }
               ],
               "removed" => [^item4]
             } =
               conn
               |> patch(~p"/api/playlists/#{playlist_id}/items", %{
                 add: [
                   %{
                     position: "e",
                     trackId: track5
                   }
                 ],
                 move: [
                   %{
                     position: "a1",
                     itemId: item3
                   }
                 ],
                 remove: [item4]
               })
               |> json_response(200)

      playlist = Playlists.get_playlist!(playlist_id)

      assert [item1, item3, item2, item5] ==
               playlist
               |> Playlists.paginate_playlists_items(%{})
               |> Map.get(:entries)
               |> Enum.map(& &1.id)
    end
  end

  describe "forbidden when not authenticated" do
    test "forbidden on /api/playlists", %{conn: conn} do
      assert_raise MusicBoxWeb.UnauthorizedError, fn ->
        get(conn, "/api/playlists")
      end
    end

    test "forbidden on /api/playlist/:playlist_id", %{conn: conn, playlist: playlist} do
      assert_raise MusicBoxWeb.UnauthorizedError, fn ->
        get(conn, "/api/playlists/#{playlist.id}")
      end
    end

    test "forbidden on /api/playlist/:playlist_id/items", %{conn: conn, playlist: playlist} do
      assert_raise MusicBoxWeb.UnauthorizedError, fn ->
        get(conn, "/api/playlists/#{playlist.id}/items")
      end
    end
  end
end
