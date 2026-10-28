defmodule OnduWeb.InfoControllerTest do
  use OnduWeb.ConnCase, async: true

  setup %{conn: conn} do
    [conn: log_in_user(conn, Ondu.AccountsFixtures.user_fixture())]
  end

  test "returns the server and api version", %{conn: conn} do
    assert %{"version" => version, "apiVersion" => 2} =
             conn |> get(~p"/api/info") |> api_response(200, "ServerInfo")

    assert version == to_string(Application.spec(:ondu, :vsn))
  end

  test "lists the transcoding presets and the default", %{conn: conn} do
    assert %{"defaultPreset" => "default_ogg", "presets" => presets} =
             conn |> get(~p"/api/info") |> api_response(200, "ServerInfo")

    assert [
             %{"id" => "default_ogg", "name" => "Default (192kbps)", "bitrate" => 192},
             %{"id" => "mobile_ogg", "name" => "Mobile (96kbps)", "bitrate" => 96}
           ] = presets
  end

  test "requires authentication" do
    assert_raise OnduWeb.UnauthorizedError, fn -> get(build_conn(), ~p"/api/info") end
  end
end
