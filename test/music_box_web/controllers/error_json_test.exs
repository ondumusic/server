defmodule MusicBoxWeb.ErrorJSONTest do
  use MusicBoxWeb.ConnCase, async: false

  test "renders 404" do
    assert MusicBoxWeb.ErrorJSON.render("404.json", %{}) == %{error: "Not Found"}
  end

  test "renders 500" do
    assert MusicBoxWeb.ErrorJSON.render("500.json", %{}) ==
             %{error: "Internal Server Error"}
  end
end
