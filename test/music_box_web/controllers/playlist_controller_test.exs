defmodule MusicBoxWeb.PlaylistControllerTest do
  use MusicBoxWeb.ConnCase, async: false

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
