defmodule MusicBoxWeb.AuthJSON do
  use MusicBoxWeb, :json

  def logged_in(%{signed_session_token: signed_session_token, current_user: current_user}) do
    %{
      ok: true,
      sessionToken: signed_session_token,
      currentUser: current_user(%{current_user: current_user})
    }
  end

  def current_user(%{current_user: current_user}) do
    %{
      id: current_user.id,
      username: current_user.username
    }
  end

  def signup(%{changeset: changeset}) do
    %{
      ok: false,
      fields: json_changeset(changeset)
    }
  end
end
