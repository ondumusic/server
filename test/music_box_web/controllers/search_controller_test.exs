defmodule MusicBoxWeb.SearchControllerTest do
  use MusicBoxWeb.ConnCase, async: true

  describe "search" do
    setup :register_and_log_in_user

    test "returns list of search results for query", %{conn: conn} do
      assert %{"results" => results} =
               conn
               |> get(~p"/api/search", %{query: "beatles"})
               |> json_response(200)

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
             ] = Enum.map(results, & &1["track"]["name"])
    end

    test "returns list of search results for artist and track name", %{conn: conn} do
      assert %{"results" => results} =
               conn
               |> get(~p"/api/search", %{query: "beatles beethoven"})
               |> json_response(200)

      assert [
               "Roll Over Beethoven"
             ] = Enum.map(results, & &1["track"]["name"])
    end

    test "returns list of search results for partial artist and track name", %{conn: conn} do
      assert %{"results" => results} =
               conn
               |> get(~p"/api/search", %{query: "beat post"})
               |> json_response(200)

      assert [
               "Please Mister Postman"
             ] = Enum.map(results, & &1["track"]["name"])
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
