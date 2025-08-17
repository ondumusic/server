defmodule MusicBoxWeb.UserAuthTest do
  use MusicBoxWeb.ConnCase

  alias MusicBox.Sessions
  alias MusicBoxWeb.UserAuth

  import MusicBox.AccountsFixtures

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, MusicBoxWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{user: user_fixture(), conn: conn}
  end

  describe "log_in_user/3" do
    test "stores the session in assigns", %{conn: conn, user: user} do
      conn = UserAuth.log_in_user(conn, user)
      assert session_token = conn.assigns.session_token
      assert Sessions.get_user_by_session_token(session_token)
    end
  end

  describe "logout_user/1" do
    test "erases session", %{conn: conn, user: user} do
      session_token = Sessions.generate_user_session_token(user)

      conn =
        conn
        |> assign(:session_token, session_token)
        |> UserAuth.log_out_user()

      refute conn.assigns[:session_token]
      refute Sessions.get_user_by_session_token(session_token)
    end

    test "works even if user is already logged out", %{conn: conn} do
      conn = conn |> UserAuth.log_out_user()
      refute conn.assigns[:session_token]
    end
  end

  describe "fetch_current_user/2" do
    test "authenticates user from session", %{conn: conn, user: user} do
      session_token = Sessions.generate_user_session_token(user)
      conn = conn |> assign(:session_token, session_token) |> UserAuth.fetch_current_user([])
      assert conn.assigns.current_user.id == user.id
    end

    test "authenticates user from header", %{conn: conn, user: user} do
      conn = UserAuth.log_in_user(conn, user)
      assert session_token = conn.assigns.session_token
      assert signed_session_token = conn.assigns.signed_session_token

      conn =
        conn
        |> put_req_header(
          "authentication",
          "bearer #{signed_session_token}"
        )
        |> UserAuth.fetch_current_user([])

      assert conn.assigns.current_user.id == user.id
      assert conn.assigns[:session_token] == session_token
      assert conn.assigns[:signed_session_token] == signed_session_token
    end

    test "does not authenticate if data is missing", %{conn: conn, user: user} do
      _ = Sessions.generate_user_session_token(user)
      conn = UserAuth.fetch_current_user(conn, [])
      refute conn.assigns[:signed_session_token]
      refute conn.assigns[:session_token]
      refute conn.assigns.current_user
    end
  end

  describe "require_authenticated_user/2" do
    test "returns error if user is not authenticated", %{conn: conn} do
      assert_raise MusicBoxWeb.UnauthorizedError, fn ->
        conn |> UserAuth.require_authenticated_user([])
      end
    end
  end
end
