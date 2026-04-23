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
               |> api_response(200, "LoginResponse")

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
               |> api_response(200, "ArtistPage")
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
               |> api_response(422, "LoginError")
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
               |> api_response(200, "LoginResponse")

      assert conn
             |> put_req_header("authorization", "Bearer #{session_token}")
             |> get(~p"/api/artists")
             |> api_response(200, "ArtistPage")

      assert %{"ok" => true} =
               conn
               |> put_req_header("authorization", "Bearer #{session_token}")
               |> delete(~p"/api/auth/session")
               |> api_response(200, "LogoutResponse")

      assert_raise MusicBoxWeb.UnauthorizedError, fn ->
        conn
        |> put_req_header("authorization", "Bearer #{session_token}")
        |> get(~p"/api/artists")
        |> api_response(200, "Unauthorized")
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
                 passwordConfirmation: "testtest123!"
               })
               |> api_response(201, "SignupResponse")
    end

    test "fails on mismatched password", %{conn: conn} do
      # Delete all users
      MusicBox.Repo.delete_all(MusicBox.Accounts.User)

      assert %{
               "ok" => false,
               "fields" => %{
                 "passwordConfirmation" => %{
                   "message" => "does not match password"
                 }
               }
             } =
               conn
               |> post(~p"/api/auth/signup", %{
                 username: "testuser",
                 password: "testtest123!",
                 passwordConfirmation: "!321tsettset"
               })
               |> api_response(422, "SignupError")
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
                 passwordConfirmation: "testtest123!"
               })
               |> api_response(422, "SignupError")
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
               |> api_response(200, "User")
    end

    test "fails if not logged in", %{} do
      assert_raise MusicBoxWeb.UnauthorizedError, fn ->
        build_conn()
        |> get(~p"/api/auth/me")
        |> api_response(200, "Unauthorized")
      end
    end
  end
end
