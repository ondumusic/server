defmodule OnduWeb.InfoControllerTest do
  use OnduWeb.ConnCase, async: true

  test "returns the server and api version", %{conn: conn} do
    conn = log_in_user(conn, Ondu.AccountsFixtures.user_fixture())

    assert %{"version" => version, "apiVersion" => 2} =
             conn |> get(~p"/api/info") |> api_response(200, "ServerInfo")

    assert version == to_string(Application.spec(:ondu, :vsn))
  end

  test "requires authentication", %{conn: conn} do
    assert_raise OnduWeb.UnauthorizedError, fn -> get(conn, ~p"/api/info") end
  end
end
