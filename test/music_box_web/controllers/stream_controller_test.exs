defmodule MusicBoxWeb.StreamControllerTest do
  use MusicBoxWeb.ConnCase, async: false

  alias MusicBox.Tracks.Track

  setup do
    track = Repo.all(Track.preloaded()) |> Enum.random()

    fixture_path =
      Path.expand("../../support/fixtures/music_files", __DIR__)
      |> Path.join("with_tags/sample.id3v24.mp3")

    file = update_record(track.file, %{path: fixture_path})
    track = %{track | file: file}
    [track: track]
  end

  describe "stream with current_user" do
    setup :register_and_log_in_user

    test "returns stream with logged in user", %{conn: conn, track: track} do
      assert get(conn, ~p"/stream/#{track}") |> response(:ok)
    end
  end

  describe "stream with playtoken" do
    setup %{conn: conn} do
      user = MusicBox.Accounts.get_user_by_username("testuser")

      conn = %{
        conn
        | secret_key_base: MusicBoxWeb.Endpoint.config(:secret_key_base),
          assigns: %{current_user: user}
      }

      token = MusicBoxWeb.PlayToken.create(conn)
      [token: token]
    end

    test "returns stream with valid token", %{conn: conn, track: track, token: token} do
      assert get(conn, ~p"/stream/#{track}?token=#{token}") |> response(:ok)
    end
  end

  describe "forbidden when not authenticated" do
    test "forbidden when no playtoken or current_user", %{conn: conn, track: track} do
      assert_raise MusicBoxWeb.ForbiddenError, fn ->
        get(conn, ~p"/stream/#{track}")
      end
    end
  end
end
