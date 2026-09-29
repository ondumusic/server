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

  describe "stream ranges" do
    setup :register_and_log_in_user

    setup %{track: track} do
      contents = File.read!(track.file.path)
      file = update_record(track.file, %{size: byte_size(contents)})
      [track: %{track | file: file}, contents: contents, size: byte_size(contents)]
    end

    defp get_range(conn, track, range) do
      conn |> put_req_header("range", range) |> get(~p"/stream/#{track}")
    end

    test "returns the requested bytes", %{conn: conn, track: track, contents: contents} do
      conn = get_range(conn, track, "bytes=10-19")

      assert response(conn, 206) == binary_part(contents, 10, 10)
      assert get_resp_header(conn, "content-range") == ["bytes 10-19/#{byte_size(contents)}"]
    end

    test "returns everything from the start byte", %{conn: conn, track: track} = ctx do
      %{contents: contents, size: size} = ctx
      conn = get_range(conn, track, "bytes=100-")

      assert response(conn, 206) == binary_part(contents, 100, size - 100)
      assert get_resp_header(conn, "content-length") == ["#{size - 100}"]
    end

    test "ends ranges at the end of the file", %{conn: conn, track: track, size: size} do
      conn = get_range(conn, track, "bytes=#{size - 5}-#{size + 100}")

      assert byte_size(response(conn, 206)) == 5
      assert get_resp_header(conn, "content-range") == ["bytes #{size - 5}-#{size - 1}/#{size}"]
    end

    test "refuses ranges starting beyond the file", %{conn: conn, track: track, size: size} do
      conn = get_range(conn, track, "bytes=#{size}-")

      assert response(conn, 416)
      assert get_resp_header(conn, "content-range") == ["bytes */#{size}"]
    end

    test "ignores invalid ranges", %{conn: conn, track: track, contents: contents} do
      assert get_range(conn, track, "bytes=20-10") |> response(200) == contents
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
