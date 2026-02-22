defmodule MusicBoxWeb.AuthControllerTest do
  use MusicBoxWeb.ConnCase, async: false

  describe "login" do
    test "can login and use session token", %{conn: conn} do
      user = MusicBox.Repo.all(MusicBox.Accounts.User) |> List.first()
      user_id = user.id
      username = user.username

      assert %{
               "currentUser" => %{"id" => ^user_id, "username" => ^username},
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
  end

  describe "logout" do
    test "can delete session token", %{conn: conn} do
      user = MusicBox.Repo.all(MusicBox.Accounts.User) |> List.first()
      user_id = user.id
      username = user.username

      assert %{
               "currentUser" => %{"id" => ^user_id, "username" => ^username},
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

  describe "signup" do
    test "creates a new user account", %{conn: conn} do
      # Delete all users
      MusicBox.Repo.delete_all(MusicBox.Accounts.User)

      assert %{
               "currentUser" => %{"id" => _user_id, "username" => "testuser"},
               "ok" => true,
               "sessionToken" => _session_token
             } =
               conn
               |> post(~p"/api/auth/signup", %{
                 username: "testuser",
                 password: "testtest123!",
                 password_confirmation: "testtest123!"
               })
               |> json_response(201)
    end

    test "fails on mismatched password", %{conn: conn} do
      # Delete all users
      MusicBox.Repo.delete_all(MusicBox.Accounts.User)

      assert %{
               "ok" => false,
               "fields" => %{
                 "password_confirmation" => %{
                   "message" => "does not match password"
                 }
               }
             } =
               conn
               |> post(~p"/api/auth/signup", %{
                 username: "testuser",
                 password: "testtest123!",
                 password_confirmation: "!321tsettset"
               })
               |> json_response(422)
    end

    test "fails on missing username", %{conn: conn} do
      # Delete all users
      MusicBox.Repo.delete_all(MusicBox.Accounts.User)

      assert %{
               "ok" => false,
               "fields" => %{
                 "username" => %{
                   "message" => "can't be blank"
                 }
               }
             } =
               conn
               |> post(~p"/api/auth/signup", %{
                 username: "",
                 password: "testtest123!",
                 password_confirmation: "testtest123!"
               })
               |> json_response(422)
    end
  end

  describe "me" do
    setup :register_and_log_in_user

    test "returns current user", %{conn: conn, user: user} do
      user_id = user.id
      username = user.username

      assert %{
               "id" => ^user_id,
               "username" => ^username
             } =
               conn
               |> get(~p"/api/auth/me")
               |> json_response(200)
    end

    test "fails if not logged in", %{} do
      assert_raise MusicBoxWeb.UnauthorizedError, fn ->
        build_conn()
        |> get(~p"/api/auth/me")
        |> json_response(200)
      end
    end
  end
end
