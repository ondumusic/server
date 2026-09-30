defmodule MusicBoxWeb.InfoControllerTest do
  use MusicBoxWeb.ConnCase, async: true

  test "returns the server and api version", %{conn: conn} do
    conn = log_in_user(conn, MusicBox.AccountsFixtures.user_fixture())

    assert %{"version" => version, "apiVersion" => 1} =
             conn |> get(~p"/api/info") |> api_response(200, "ServerInfo")

    assert version == to_string(Application.spec(:music_box, :vsn))
  end

  test "requires authentication", %{conn: conn} do
    assert_raise MusicBoxWeb.UnauthorizedError, fn -> get(conn, ~p"/api/info") end
  end
end
