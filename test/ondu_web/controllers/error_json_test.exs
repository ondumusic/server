defmodule OnduWeb.ErrorJSONTest do
  use OnduWeb.ConnCase, async: false

  test "renders 404" do
    assert OnduWeb.ErrorJSON.render("404.json", %{}) == %{error: "Not Found"}
  end

  test "renders 500" do
    assert OnduWeb.ErrorJSON.render("500.json", %{}) ==
             %{error: "Internal Server Error"}
  end
end
