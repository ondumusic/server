defmodule MusicBoxWeb.HealthControllerTest do
  use MusicBoxWeb.ConnCase, async: true

  test "responds without being logged in", %{conn: conn} do
    assert conn |> get(~p"/health") |> text_response(200) == "ok"
  end
end
