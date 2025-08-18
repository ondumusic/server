defmodule MusicBoxWeb.AuthControllerTest do
  use MusicBoxWeb.ConnCase, async: true

  describe "auth controller" do
    test "can login and use session token", %{conn: conn} do
      user = MusicBox.Repo.all(MusicBox.Accounts.User) |> List.first()
      user_id = user.id
      username = user.username

      assert %{
               "current_user" => %{"id" => ^user_id, "username" => ^username},
               "ok" => true,
               "sessionToken" => session_token
             } =
               conn
               |> post(~p"/api/auth/login", %{
                 username: user.username,
                 password: "testtest123!"
               })
               |> json_response(200)

      assert %{
               "entries" => [
                 %{
                   "name" => "The Beatles",
                   "slug" => "the-beatles"
                 }
               ]
             } =
               conn
               |> put_req_header("authorization", "Bearer #{session_token}")
               |> get(~p"/api/artists")
               |> json_response(200)
    end

    test "refuses bad login", %{conn: conn} do
      assert %{
               "ok" => false,
               "fields" => %{"password" => %{"message" => "Invalid username or password"}}
             } =
               conn
               |> post(~p"/api/auth/login", %{
                 username: "root",
                 password: "hunter2"
               })
               |> json_response(200)
    end

    test "can delete session token", %{conn: conn} do
      user = MusicBox.Repo.all(MusicBox.Accounts.User) |> List.first()
      user_id = user.id
      username = user.username

      assert %{
               "current_user" => %{"id" => ^user_id, "username" => ^username},
               "ok" => true,
               "sessionToken" => session_token
             } =
               conn
               |> post(~p"/api/auth/login", %{
                 username: user.username,
                 password: "testtest123!"
               })
               |> json_response(200)

      assert conn
             |> put_req_header("authorization", "Bearer #{session_token}")
             |> get(~p"/api/artists")
             |> json_response(200)

      assert %{"ok" => true} =
               conn
               |> put_req_header("authorization", "Bearer #{session_token}")
               |> delete(~p"/api/auth/session")
               |> json_response(200)

      assert_raise MusicBoxWeb.UnauthorizedError, fn ->
        conn
        |> put_req_header("authorization", "Bearer #{session_token}")
        |> get(~p"/api/artists")
        |> json_response(200)
      end
    end
  end
end
