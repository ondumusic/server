defmodule MusicBoxWeb.UserController do
  use MusicBoxWeb, :controller

  alias MusicBox.Accounts
  alias MusicBoxWeb.UserAuth

  operation :update_password,
    summary: "Update your password",
    tags: ["Auth"],
    request_body: {"Password params", "application/json", Schemas.UpdatePasswordRequest},
    responses: [
      ok: {"Succesfully updated password.", "application/json", Schemas.UpdatePasswordResponse},
      unauthorized: {"Failed to authenticate.", "application/json", Schemas.Error},
      unprocessable_entity:
        {"Validation failed.", "application/json", Schemas.UpdatePasswordError}
    ]

  def update_password(conn, params) do
    case Accounts.update_user_password(conn.assigns.current_user, params) do
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:changeset, changeset: changeset)

      {:ok, user} ->
        conn
        |> UserAuth.log_in_user(user)
        |> render(:update_password)
    end
  end
end
