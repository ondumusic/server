defmodule MusicBoxWeb.PlaylistControllerTest do
  use MusicBoxWeb.ConnCase, async: false

  alias MusicBox.Playlists
  alias MusicBox.Playlists.{Playlist, PlaylistItem}

  setup tags do
    playlist =
      unless tags[:skip_playlist] do
        tracks = MusicBox.Tracks.paginate_tracks(%{}).entries

        items =
          tracks
          |> Enum.filter(&(&1.number in [4, 8, 9]))
          |> Enum.zip(["a2", "a1", "a0"])
          |> Enum.map(fn {track, position} ->
            %{
              position: position,
              track_id: track.id
            }
          end)

        TestSeeds.insert_playlist(%{
          name: "Test Playlist",
          items: items
        })
      end

    [playlist: playlist]
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
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
                 %{"position" => "a0"},
                 %{"position" => "a1"},
                 %{"position" => "a2"}
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

    @tag :skip_playlist
    test "deletes playlist folder (and contents)", %{conn: conn} do
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
               "id" => chill_id,
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

      [track | _tracks] = MusicBox.Tracks.paginate_tracks(%{}).entries
      playlist = Playlists.get_playlist!(chill_id)

      Playlists.update_playlist_items(playlist, %{
        add: [
          %{track_id: track.id, position: "a0"}
        ]
      })

      assert conn
             |> delete(~p"/api/playlists/#{moods_id}")
             |> response(204)

      # Should only contain the default created one
      assert Repo.aggregate(Playlist, :count) == 0
      assert Repo.aggregate(PlaylistItem, :count) == 0
    end
  end

  describe "playlist items" do
    setup :register_and_log_in_user

    test "can add items to playlist", %{conn: conn, playlist: playlist} do
      track = MusicBox.Tracks.paginate_tracks(%{}).entries |> Enum.find(&(&1.number == 5))
      position = "a3"
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
      position = "a3"
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
      position = "a6"
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
      [item1, item2, item3] = playlist.items
      item1_id = item1.id
      item2_id = item2.id
      item3_id = item3.id

      assert %{
               "ok" => true,
               "added" => [],
               "moved" => [],
               "removed" => [^item1_id]
             } =
               conn
               |> patch(~p"/api/playlists/#{playlist.id}/items", %{
                 remove: [item1_id]
               })
               |> api_response(200, "UpdatePlaylistItemsResponse")

      assert %{entries: [_a, _b]} = Playlists.paginate_playlists_items(playlist, %{})
      assert Playlists.get_playlist!(playlist.id).track_count == 2

      assert %{
               "ok" => true,
               "added" => [],
               "moved" => [],
               "removed" => [^item3_id, ^item2_id]
             } =
               conn
               |> patch(~p"/api/playlists/#{playlist.id}/items", %{
                 remove: [item2_id, item3_id]
               })
               |> api_response(200, "UpdatePlaylistItemsResponse")

      assert %{entries: []} = Playlists.paginate_playlists_items(playlist, %{})
      assert Playlists.get_playlist!(playlist.id).track_count == 0
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
                     position: "a0",
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
                     position: "a0"
                   }
                 ]
               })
               |> api_response(422, "UpdatePlaylistItemsError")
    end

    test "ensures positions are unique", %{conn: conn, playlist: playlist} do
      track = MusicBox.Tracks.paginate_tracks(%{}).entries |> Enum.find(&(&1.number == 5))
      position = "a0"
      track_id = track.id

      assert %{
               "ok" => true,
               "added" => [
                 %{
                   "trackId" => ^track_id,
                   "position" => "a0V"
                 }
               ]
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

      %{entries: entries} = Playlists.paginate_playlists_items(playlist, %{})
      assert Enum.at(entries, 0).position == "a0"
      assert Enum.at(entries, 1).position == "a0V"
      assert Enum.at(entries, 1).track_id == track_id
      assert Enum.at(entries, 2).position == "a1"
      assert Enum.at(entries, 3).position == "a2"
    end

    @tag :skip_playlist
    test "ensures positions are unique (next calculated also taken)", %{conn: conn} do
      tracks = MusicBox.Tracks.paginate_tracks(%{}).entries

      items =
        tracks
        |> Enum.filter(&(&1.number in [4, 8, 9]))
        |> Enum.zip(["a0", "a0V", "a1"])
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

      track = Enum.find(tracks, &(&1.number == 5))
      track_id = track.id
      position = "a0"

      assert %{
               "ok" => true,
               "added" => [
                 %{
                   "trackId" => ^track_id,
                   "position" => "a0G"
                 }
               ]
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

      %{entries: entries} = Playlists.paginate_playlists_items(playlist, %{})
      assert Enum.at(entries, 0).position == "a0"
      assert Enum.at(entries, 1).position == "a0G"
      assert Enum.at(entries, 1).track_id == track_id
      assert Enum.at(entries, 2).position == "a0V"
      assert Enum.at(entries, 3).position == "a1"
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

    test "validates position value", %{conn: conn, playlist: playlist} do
      item = List.first(playlist.items)
      item_id = item.id

      assert %{
               "ok" => false,
               "error" => "invalid_positions",
               "positions" => ["q1"]
             } =
               conn
               |> patch(~p"/api/playlists/#{playlist.id}/items", %{
                 move: [
                   %{
                     position: "q1",
                     itemId: item_id
                   }
                 ]
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
                   "position" => "a0",
                   "trackId" => ^track1
                 },
                 %{
                   "id" => item2,
                   "position" => "a1",
                   "trackId" => ^track2
                 },
                 %{
                   "id" => item3,
                   "position" => "a2",
                   "trackId" => ^track3
                 },
                 %{
                   "id" => item4,
                   "position" => "a3",
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
                     position: "a0",
                     trackId: track1
                   },
                   %{
                     position: "a1",
                     trackId: track2
                   },
                   %{
                     position: "a2",
                     trackId: track3
                   },
                   %{
                     position: "a3",
                     trackId: track4
                   }
                 ]
               })
               |> api_response(200, "UpdatePlaylistItemsResponse")

      assert %{
               "ok" => true,
               "added" => [
                 %{
                   "position" => "a5",
                   "id" => item5,
                   "trackId" => ^track5
                 }
               ],
               "moved" => [
                 %{
                   "position" => "a6",
                   "id" => ^item3
                 }
               ],
               "removed" => [^item4]
             } =
               conn
               |> patch(~p"/api/playlists/#{playlist_id}/items", %{
                 add: [
                   %{
                     position: "a5",
                     trackId: track5
                   }
                 ],
                 move: [
                   %{
                     position: "a6",
                     itemId: item3
                   }
                 ],
                 remove: [item4]
               })
               |> api_response(200, "UpdatePlaylistItemsResponse")

      playlist = Playlists.get_playlist!(playlist_id)

      assert [item1, item2, item5, item3] ==
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
