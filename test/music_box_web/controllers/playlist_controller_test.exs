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
                   "trackCount" => 3,
                   "name" => "Test Playlist"
                 }
               ]
             } =
               conn
               |> get(~p"/api/playlists")
               |> api_response(200, "PlaylistPage")
    end

    test "returns paginated list of playlists (excludes children)", %{conn: conn} do
      {:ok, folder} =
        Playlists.create_playlist(%{
          name: "Folder 1",
          is_folder: true
        })

      {:ok, _subfolder} =
        Playlists.create_playlist(%{
          name: "Subfolder 1",
          parent_id: folder.id,
          is_folder: true
        })

      {:ok, _subplaylist} =
        Playlists.create_playlist(%{
          name: "Subplaylist 1",
          parent_id: folder.id
        })

      assert %{
               "pageNumber" => 1,
               "totalPages" => 1,
               "totalEntries" => 2,
               "pageSize" => 100,
               "entries" => [
                 %{
                   "trackCount" => 0,
                   "name" => "Folder 1"
                 },
                 %{
                   "trackCount" => 3,
                   "name" => "Test Playlist"
                 }
               ]
             } =
               conn
               |> get(~p"/api/playlists")
               |> api_response(200, "PlaylistPage")
    end

    test "returns paginated list of playlists for given parent_id", %{conn: conn} do
      {:ok, folder} =
        Playlists.create_playlist(%{
          name: "Folder 1",
          is_folder: true
        })

      {:ok, _subfolder} =
        Playlists.create_playlist(%{
          name: "Subfolder 1",
          parent_id: folder.id,
          is_folder: true
        })

      {:ok, _subplaylist} =
        Playlists.create_playlist(%{
          name: "Subplaylist 1",
          parent_id: folder.id
        })

      assert %{
               "pageNumber" => 1,
               "totalPages" => 1,
               "totalEntries" => 2,
               "pageSize" => 100,
               "entries" => [
                 %{
                   "trackCount" => 0,
                   "name" => "Subfolder 1"
                 },
                 %{
                   "trackCount" => 0,
                   "name" => "Subplaylist 1"
                 }
               ]
             } =
               conn
               |> get(~p"/api/playlists?parent_id=#{folder.id}")
               |> api_response(200, "PlaylistPage")
    end

    test "returns playlist details", %{conn: conn, playlist: playlist} do
      assert %{
               "trackCount" => 3,
               "name" => "Test Playlist"
             } =
               conn
               |> get(~p"/api/playlists/#{playlist.id}")
               |> api_response(200, "Playlist")
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
               |> api_response(200, "PlaylistItemPage")
    end

    test "creates playlist", %{conn: conn} do
      assert %{"fields" => %{"name" => %{"message" => "can't be blank"}}} =
               conn
               |> post(~p"/api/playlists", %{
                 name: ""
               })
               |> api_response(422, "CreatePlaylistError")

      assert %{
               "name" => "My Faves"
             } =
               conn
               |> post(~p"/api/playlists", %{
                 name: "My Faves"
               })
               |> api_response(201, "Playlist")
    end

    test "creates playlist folder", %{conn: conn} do
      assert %{
               "id" => moods_id,
               "name" => "Moods",
               "isFolder" => true,
               "trackCount" => 0
             } =
               conn
               |> post(~p"/api/playlists", %{
                 name: "Moods",
                 isFolder: true
               })
               |> api_response(201, "Playlist")

      assert %{
               "name" => "Happy Songs",
               "isFolder" => false,
               "parentId" => ^moods_id
             } =
               conn
               |> post(~p"/api/playlists", %{
                 name: "Happy Songs",
                 parentId: moods_id
               })
               |> api_response(201, "Playlist")
    end

    test "creates playlist sub folder", %{conn: conn} do
      assert %{
               "id" => moods_id,
               "name" => "Moods",
               "isFolder" => true
             } =
               conn
               |> post(~p"/api/playlists", %{
                 name: "Moods",
                 isFolder: true
               })
               |> api_response(201, "Playlist")

      assert %{
               "name" => "Chill",
               "isFolder" => true,
               "parentId" => ^moods_id
             } =
               conn
               |> post(~p"/api/playlists", %{
                 name: "Chill",
                 isFolder: true,
                 parentId: moods_id
               })
               |> api_response(201, "Playlist")
    end

    test "updates playlist", %{conn: conn, playlist: playlist} do
      assert %{"fields" => %{"name" => %{"message" => "can't be blank"}}} =
               conn
               |> patch(~p"/api/playlists/#{playlist.id}", %{
                 name: ""
               })
               |> api_response(422, "UpdatePlaylistError")

      assert %{
               "name" => "My New Faves"
             } =
               conn
               |> patch(~p"/api/playlists/#{playlist.id}", %{
                 name: "My New Faves"
               })
               |> api_response(200, "Playlist")
    end

    test "cannot update playlist isFolder", %{conn: conn, playlist: playlist} do
      assert %{
               "fields" => %{
                 "isFolder" => %{"message" => "cannot change existing playlist into folder"}
               }
             } =
               conn
               |> patch(~p"/api/playlists/#{playlist.id}", %{
                 isFolder: true
               })
               |> api_response(422, "UpdatePlaylistError")
    end

    test "cannot use non-folder playlist as parent folder", %{conn: conn, playlist: playlist} do
      assert %{
               "fields" => %{
                 "parentId" => %{"message" => "is not a folder"}
               }
             } =
               conn
               |> patch(~p"/api/playlists/#{playlist.id}", %{
                 parentId: playlist.id
               })
               |> api_response(422, "UpdatePlaylistError")
    end

    test "deletes playlist", %{conn: conn, playlist: playlist} do
      assert conn
             |> delete(~p"/api/playlists/#{playlist.id}")
             |> response(204)

      assert Repo.aggregate(Playlist, :count) == 0
    end
  end

  describe "playlist items" do
    setup :register_and_log_in_user

    test "can add items to playlist", %{conn: conn, playlist: playlist} do
      track = MusicBox.Tracks.paginate_tracks(%{}).entries |> Enum.find(&(&1.number == 5))
      position = "d"
      track_id = track.id

      playlist =
        update_record(playlist, %{
          updated_at: DateTime.shift(playlist.updated_at, minute: 1)
        })

      assert playlist.track_count == 3

      assert %{
               "ok" => true,
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
               |> api_response(200, "UpdatePlaylistItemsResponse")

      updated_playlist = Playlists.get_playlist!(playlist.id)
      assert playlist.track_count < updated_playlist.track_count
      assert playlist.updated_at != updated_playlist.updated_at
    end

    test "cannot add items to playlist folder", %{conn: conn, playlist: playlist} do
      playlist = update_record(playlist, %{is_folder: true})

      track = MusicBox.Tracks.paginate_tracks(%{}).entries |> Enum.find(&(&1.number == 5))
      position = "d"
      track_id = track.id

      assert %{
               "ok" => false,
               "error" => "playlist_is_folder"
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
               |> api_response(422, "UpdatePlaylistItemsError")
    end

    test "can move items in playlist", %{conn: conn, playlist: playlist} do
      item = List.first(playlist.items)
      position = "q"
      item_id = item.id

      assert %{
               "ok" => true,
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
               |> api_response(200, "UpdatePlaylistItemsResponse")
    end

    test "can remove items from playlist", %{conn: conn, playlist: playlist} do
      item = List.first(playlist.items)
      item_id = item.id

      assert %{
               "ok" => true,
               "added" => [],
               "moved" => [],
               "removed" => [^item_id]
             } =
               conn
               |> patch(~p"/api/playlists/#{playlist.id}/items", %{
                 remove: [item_id]
               })
               |> api_response(200, "UpdatePlaylistItemsResponse")

      assert %{entries: [_a, _b]} = Playlists.paginate_playlists_items(playlist, %{})
    end

    test "cannot move and remove same item in playlist", %{conn: conn, playlist: playlist} do
      item = List.first(playlist.items)
      position = "q"
      item_id = item.id

      assert %{
               "ok" => false,
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
               |> api_response(422, "UpdatePlaylistItemsError")
    end

    test "cannot move unknown items", %{conn: conn, playlist: playlist} do
      item_id = Ecto.UUID.generate()

      assert %{
               "ok" => false,
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
               |> api_response(422, "UpdatePlaylistItemsError")
    end

    test "cannot remove unknown items", %{conn: conn, playlist: playlist} do
      item_id = Ecto.UUID.generate()

      assert %{
               "ok" => false,
               "error" => "unknown_items",
               "itemIds" => [^item_id]
             } =
               conn
               |> patch(~p"/api/playlists/#{playlist.id}/items", %{
                 remove: [item_id]
               })
               |> api_response(422, "UpdatePlaylistItemsError")
    end

    test "cannot add unknown tracks", %{conn: conn, playlist: playlist} do
      track_id = Ecto.UUID.generate()

      assert %{
               "ok" => false,
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
               |> api_response(422, "UpdatePlaylistItemsError")
    end

    test "ensures positions are unique", %{conn: conn, playlist: playlist} do
      track = MusicBox.Tracks.paginate_tracks(%{}).entries |> Enum.find(&(&1.number == 5))
      position = "a"
      track_id = track.id

      assert %{
               "ok" => false,
               "error" => "add_move_conflict",
               "positions" => ["a"]
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
               |> api_response(422, "UpdatePlaylistItemsError")
    end

    test "restrict amount of operations per request", %{conn: conn, playlist: playlist} do
      TestSeeds.generate_artists(100)

      tracks =
        for page <- 1..6 do
          MusicBox.Tracks.paginate_tracks(%{page: page}).entries
        end
        |> List.flatten()
        |> Enum.with_index()
        |> Enum.map(fn {item, i} ->
          %{
            position: gen_id(i),
            trackId: item.id
          }
        end)

      assert %{
               "ok" => false,
               "error" => "too_many_operations",
               "limit" => 250,
               "count" => 300
             } =
               conn
               |> patch(~p"/api/playlists/#{playlist.id}/items", %{
                 add: tracks
               })
               |> api_response(422, "UpdatePlaylistItemsError")
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
               |> api_response(201, "Playlist")

      assert %{
               "ok" => true,
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
               |> api_response(200, "UpdatePlaylistItemsResponse")

      assert %{
               "ok" => true,
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
               |> api_response(200, "UpdatePlaylistItemsResponse")

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

  @chars ~c"ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
  defp gen_id(i) do
    base = length(@chars)
    <<Enum.at(@chars, div(i, base)), Enum.at(@chars, rem(i, base))>>
  end
end
