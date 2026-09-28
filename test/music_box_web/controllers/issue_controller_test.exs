defmodule MusicBoxWeb.IssueControllerTest do
  use MusicBoxWeb.ConnCase, async: false

  alias MusicBox.Albums
  alias MusicBox.Albums.Album
  alias MusicBox.Tracks.Track

  describe "issues" do
    setup :register_and_log_in_user

    setup do
      album = Repo.get_by!(Album, slug: "with-the-beatles")

      {:ok, _artwork} =
        Albums.update_artwork(album, %{
          hash: "4f1c2a9d8e7b6c5a",
          width: 640,
          height: 571,
          fetcher: :embedded,
          last_fetch_attempt: DateTime.utc_now()
        })

      Repo.get_by!(Track, name: "Little Child") |> update_record(%{number: nil})
      TestSeeds.insert_track(nil, nil, %{name: "01 Untagged.m4a", title: nil})

      [album: album]
    end

    test "returns albums and tracks with issues", %{conn: conn, album: album} do
      album_id = album.id
      track_id = Repo.get_by!(Track, name: "01 Untagged.m4a").id
      little_child_id = Repo.get_by!(Track, name: "Little Child").id

      assert %{
               "__type" => "page",
               "__subtype" => "issues",
               "pageNumber" => 1,
               "pageSize" => 50,
               "totalEntries" => 2,
               "totalPages" => 1,
               "entries" => [
                 %{
                   "__type" => "trackIssues",
                   "track" => %{
                     "id" => ^track_id,
                     "name" => "01 Untagged.m4a",
                     "path" => "/Path/to/Music/01 Untagged.m4a.mp3"
                   },
                   "issues" => [
                     %{"code" => "title_missing", "details" => %{}},
                     %{"code" => "artist_missing", "details" => %{}}
                   ]
                 },
                 %{
                   "__type" => "albumIssues",
                   "album" => %{"id" => ^album_id, "name" => "With the Beatles"},
                   "artist" => %{"name" => "The Beatles"},
                   "issues" => [
                     %{
                       "code" => "artwork_not_square",
                       "details" => %{"width" => 640, "height" => 571}
                     },
                     %{
                       "code" => "track_number_missing",
                       "details" => %{"trackIds" => [^little_child_id]}
                     },
                     %{
                       "code" => "track_number_gap",
                       "details" => %{"disc" => 1, "numbers" => [5]}
                     }
                   ]
                 }
               ]
             } =
               conn
               |> get(~p"/api/issues")
               |> api_response(200, "IssuePage")
    end

    test "filters by code", %{conn: conn} do
      assert %{"totalEntries" => 1, "entries" => [%{"__type" => "trackIssues"}]} =
               conn
               |> get(~p"/api/issues?code=artist_missing")
               |> api_response(200, "IssuePage")
    end
  end

  test "requires authentication", %{conn: conn} do
    assert_raise MusicBoxWeb.UnauthorizedError, fn ->
      get(conn, ~p"/api/issues")
    end
  end
end
