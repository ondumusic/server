defmodule MusicBoxWeb.UserControllerTest do
  use MusicBoxWeb.ConnCase, async: false

  alias MusicBox.Sessions.Session

  describe "update_password" do
    setup :register_and_log_in_user

    test "can change password", %{conn: conn, user: user} do
      session_tokens = Repo.all(Session)

      assert %{
               "ok" => true,
               "sessionToken" => _session_token
             } =
               conn
               |> patch(~p"/api/user/password", %{
                 password: "mynewpassword42!",
                 passwordConfirmation: "mynewpassword42!",
                 currentPassword: "itsamemario!"
               })
               |> api_response(200, "UpdatePasswordResponse")

      # Changing password should invalidate existing sessions
      # and return a new session for current user
      refute Repo.get(Session, hd(session_tokens).id)
      assert session_tokens != Repo.all(Session)

      # Make sure new password works when logging in
      assert %{
               "ok" => true
             } =
               conn
               |> post(~p"/api/auth/login", %{
                 username: user.username,
                 password: "mynewpassword42!"
               })
               |> api_response(200, "LoginResponse")
    end

    test "cannot change password without valid current password", %{conn: conn} do
      assert %{
               "ok" => false,
               "fields" => %{"currentPassword" => %{"message" => "is not valid"}}
             } =
               conn
               |> patch(~p"/api/user/password", %{
                 password: "mynewpassword42!",
                 passwordConfirmation: "mynewpassword42!",
                 currentPassword: "iforgot!"
               })
               |> api_response(422, "UpdatePasswordError")
    end

    test "cannot change password without a password confirmation", %{conn: conn} do
      assert %{
               "ok" => false,
               "fields" => %{"passwordConfirmation" => %{"message" => "does not match password"}}
             } =
               conn
               |> patch(~p"/api/user/password", %{
                 password: "mynewpassword42!",
                 currentPassword: "itsamemario!"
               })
               |> api_response(422, "UpdatePasswordError")
    end
  end
end
