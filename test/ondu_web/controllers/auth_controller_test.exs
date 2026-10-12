defmodule OnduWeb.AuthControllerTest do
  use OnduWeb.ConnCase, async: false

  describe "login" do
    test "can login and use session token", %{conn: conn} do
      user = Ondu.Repo.all(Ondu.Accounts.User) |> List.first()
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

    test "refuses logins after too many failed attempts", %{conn: conn} do
      on_exit(&OnduWeb.LoginLimiter.succeeded/0)
      for _ <- 1..10, do: OnduWeb.LoginLimiter.failed()

      conn =
        post(conn, ~p"/api/auth/login", %{
          username: "testuser",
          password: "testtest123!"
        })

      assert %{"ok" => false, "fields" => %{"password" => %{"message" => "Too many" <> _}}} =
               api_response(conn, 429, "LoginError")

      assert [retry_after] = get_resp_header(conn, "retry-after")
      assert String.to_integer(retry_after) in 1..900
    end
  end

  describe "logout" do
    test "can delete session token", %{conn: conn} do
      user = Ondu.Repo.all(Ondu.Accounts.User) |> List.first()
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

      assert_raise OnduWeb.UnauthorizedError, fn ->
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
      Ondu.Repo.delete_all(Ondu.Accounts.User)

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
      Ondu.Repo.delete_all(Ondu.Accounts.User)

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
      Ondu.Repo.delete_all(Ondu.Accounts.User)

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
      assert_raise OnduWeb.UnauthorizedError, fn ->
        build_conn()
        |> get(~p"/api/auth/me")
        |> api_response(200, "Unauthorized")
      end
    end
  end
end
