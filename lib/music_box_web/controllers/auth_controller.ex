defmodule MusicBoxWeb.AuthController do
  use MusicBoxWeb, :controller

  alias MusicBox.Accounts
  alias MusicBoxWeb.UserAuth

  def login(conn, %{"username" => username, "password" => password}) do
    if user = Accounts.get_user_by_username_and_password(username, password) do
      conn
      |> UserAuth.log_in_user(user)
      |> render(:logged_in)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      # render(conn, :new, error_message: "Invalid email or password")
      conn
      |> json(%{error: true})
    end
  end
end
