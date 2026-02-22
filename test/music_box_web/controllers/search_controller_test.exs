defmodule MusicBoxWeb.SearchControllerTest do
  use MusicBoxWeb.ConnCase, async: true

  describe "search" do
    setup :register_and_log_in_user

    test "returns list of search results for query", %{conn: conn} do
      assert %{"tracks" => tracks, "albums" => albums, "artists" => artists} =
               conn
               |> get(~p"/api/search", %{query: "beatles"})
               |> json_response(200)

      assert [
               "The Beatles"
             ] = Enum.map(artists, & &1["name"])

      assert [
               "With the Beatles"
             ] = Enum.map(albums, & &1["name"])

      assert [
               "Little Child",
               "All My Loving",
               "Please Mister Postman",
               "Roll Over Beethoven",
               "Hold Me Tight",
               "Don't Bother Me",
               "Till There Was You",
               "Devil In Her Heart",
               "Not a Second Time",
               "It Won't Be Long",
               "I Wanna Be Your Man",
               "All I've Got To Do",
               "Money (That's What I Want)",
               "You've Really Got a Hold on Me"
             ] = Enum.map(tracks, & &1["name"])
    end

    test "returns list of search results for artist and track name", %{conn: conn} do
      assert %{"tracks" => tracks, "albums" => albums, "artists" => artists} =
               conn
               |> get(~p"/api/search", %{query: "beatles beethoven"})
               |> json_response(200)

      assert Enum.empty?(albums)
      assert Enum.empty?(artists)

      assert [
               "Roll Over Beethoven"
             ] = Enum.map(tracks, & &1["name"])
    end

    test "returns list of search results for partial artist and track name", %{conn: conn} do
      assert %{"tracks" => tracks, "albums" => albums, "artists" => artists} =
               conn
               |> get(~p"/api/search", %{query: "beat post"})
               |> json_response(200)

      assert Enum.empty?(albums)
      assert Enum.empty?(artists)

      assert [
               "Please Mister Postman"
             ] = Enum.map(tracks, & &1["name"])
    end
  end

  describe "forbidden when not authenticated" do
    test "forbidden on /api/search", %{conn: conn} do
      assert_raise MusicBoxWeb.UnauthorizedError, fn ->
        get(conn, "/api/search")
      end
    end
  end
end
