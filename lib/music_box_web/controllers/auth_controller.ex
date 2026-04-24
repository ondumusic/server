defmodule MusicBoxWeb.AuthController do
  use MusicBoxWeb, :controller

  alias MusicBox.Accounts
  alias MusicBox.Sessions
  alias MusicBoxWeb.UserAuth

  operation :login,
    summary: "Login",
    tags: ["Auth"],
    security: [],
    request_body: {"Login params", "application/json", Schemas.LoginRequest},
    responses: [
      ok: {"LoginResponse", "application/json", Schemas.LoginResponse},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      unprocessable_entity: {"Validation Error", "application/json", Schemas.LoginError}
    ]

  def login(conn, %{"username" => username, "password" => password}) do
    if user = Accounts.get_user_by_username_and_password(username, password) do
      conn
      |> UserAuth.log_in_user(user)
      |> render(:logged_in)
    else
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{
        ok: false,
        fields: %{
          password: %{message: "Invalid username or password"}
        }
      })
    end
  end

  operation :current_user,
    summary: "Get current user",
    tags: ["Auth"],
    responses: [
      ok: {"CurrentUser", "application/json", Schemas.User},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]

  def current_user(conn, _params) do
    conn
    |> render(:current_user)
  end

  operation :signup,
    summary: "Signup",
    tags: ["Auth"],
    security: [],
    request_body: {"Signup params", "application/json", Schemas.SignupRequest},
    responses: [
      created: {"SignupResponse", "application/json", Schemas.SignupResponse},
      conflict: {"Conflict", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      unprocessable_entity: {"Validation Error", "application/json", Schemas.SignupError}
    ]

  def signup(conn, params) do
    # Single-user setups only, so disable signup if we already have a user
    if Accounts.has_user?() do
      raise MusicBoxWeb.ConflictError
    end

    case Accounts.register_user(params) do
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:signup, changeset: changeset)

      {:ok, user} ->
        conn
        |> UserAuth.log_in_user(user)
        |> put_status(:created)
        |> render(:logged_in)
    end
  end

  operation :logout,
    summary: "Logout",
    tags: ["Auth"],
    responses: [
      ok: {"LogoutResponse", "application/json", Schemas.LogoutResponse},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]

  def logout(conn, _params) do
    with %{session_token: session_token} <- conn.assigns do
      Sessions.delete_user_session_token(session_token)
    end

    json(conn, %{ok: true})
  end

  operation :play_token,
    summary: "Get a playtoken",
    tags: ["Auth"],
    responses: [
      ok: {"PlayTokenResponse", "application/json", Schemas.PlayTokenResponse},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]

  def play_token(conn, _params) do
    play_token = MusicBoxWeb.PlayToken.create(conn)
    json(conn, %{ok: true, playToken: play_token})
  end
end
