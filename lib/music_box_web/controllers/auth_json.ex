defmodule MusicBoxWeb.AuthJSON do
  def logged_in(%{signed_session_token: signed_session_token, current_user: current_user}) do
    %{
      sessionToken: signed_session_token,
      loggedIn: true,
      current_user: current_user(%{current_user: current_user})
    }
  end

  def current_user(%{current_user: current_user}) do
    %{
      id: current_user.id,
      username: current_user.username
    }
  end
end
