defmodule MusicBoxWeb.AuthController do
  use MusicBoxWeb, :controller

  alias MusicBox.Accounts
  alias MusicBox.Sessions
  alias MusicBoxWeb.UserAuth

  def login(conn, %{"username" => username, "password" => password}) do
    if user = Accounts.get_user_by_username_and_password(username, password) do
      conn
      |> UserAuth.log_in_user(user)
      |> render(:logged_in)
    else
      conn
      |> json(%{
        ok: false,
        fields: %{
          password: %{message: "Invalid username or password"}
        }
      })
    end
  end

  def logout(conn, _params) do
    with %{session_token: session_token} <- conn.assigns,
         :ok <- Sessions.delete_user_session_token(session_token) do
      :ok
    end

    json(conn, %{ok: true})
  end
end
