defmodule OnduWeb.HealthControllerTest do
  use OnduWeb.ConnCase, async: true

  test "responds without being logged in", %{conn: conn} do
    assert conn |> get(~p"/health") |> text_response(200) == "ok"
  end
end
