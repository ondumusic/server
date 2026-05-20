defmodule MusicBoxWeb.UserJSON do
  use MusicBoxWeb, :json

  def update_password(%{signed_session_token: signed_session_token}) do
    %{
      ok: true,
      sessionToken: signed_session_token
    }
  end

  def changeset(%{changeset: changeset}) do
    %{
      ok: false,
      fields: json_changeset(changeset)
    }
  end
end
