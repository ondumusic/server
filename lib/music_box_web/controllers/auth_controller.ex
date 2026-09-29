defmodule MusicBoxWeb.AuthController do
  use MusicBoxWeb, :controller

  alias MusicBox.Accounts
  alias MusicBox.Accounts.User
  alias MusicBox.Sessions
  alias MusicBoxWeb.LoginLimiter
  alias MusicBoxWeb.PlayToken
  alias MusicBoxWeb.UserAuth

  operation :login,
    summary: "Login",
    tags: ["Auth"],
    security: [],
    request_body: {"Login params", "application/json", Schemas.LoginRequest},
    responses: [
      ok: {"Succesful login attempt.", "application/json", Schemas.LoginResponse},
      unauthorized: {"Failed to authenticate.", "application/json", Schemas.Error},
      unprocessable_entity: {"Validation failed.", "application/json", Schemas.LoginError},
      too_many_requests:
        {"Too many failed login attempts.", "application/json", Schemas.LoginError}
    ]

  def login(conn, %{"username" => username, "password" => password}) do
    with :ok <- LoginLimiter.check(),
         %User{} = user <- Accounts.get_user_by_username_and_password(username, password) do
      LoginLimiter.succeeded()

      conn
      |> UserAuth.log_in_user(user)
      |> render(:logged_in)
    else
      {:error, retry_after} ->
        minutes = ceil(retry_after / 60)

        conn
        |> put_status(:too_many_requests)
        |> put_resp_header("retry-after", "#{retry_after}")
        |> login_error("Too many failed login attempts, try again in #{minutes} minute(s)")

      nil ->
        LoginLimiter.failed()

        conn
        |> put_status(:unprocessable_entity)
        |> login_error("Invalid username or password")
    end
  end

  operation :current_user,
    summary: "Get current user",
    tags: ["Auth"],
    responses: [
      ok: {"The authenticated user's profile.", "application/json", Schemas.User},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error}
    ]

  def current_user(conn, _params) do
    conn
    |> render(:current_user)
  end

  operation :signup,
    summary: "Signup",
    description: """
    This only works if there is no user present yet, during onboarding. For the
    time being this is designed as a single-user application.
    """,
    tags: ["Auth"],
    security: [],
    request_body: {"Signup params", "application/json", Schemas.SignupRequest},
    responses: [
      created:
        {"Successful signup returns `currentUser` and `sessionToken`. ", "application/json",
         Schemas.SignupResponse},
      conflict: {"Signup has been disabled.", "application/json", Schemas.Error},
      unprocessable_entity: {"Validation failed.", "application/json", Schemas.SignupError}
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
    description: """
    This only revokes the current `sessionToken` for the logged-in user.
    """,
    tags: ["Auth"],
    responses: [
      ok: {"Revoked the current `sessionToken`.", "application/json", Schemas.LogoutResponse}
    ]

  def logout(conn, _params) do
    with %{session_token: session_token} <- conn.assigns do
      Sessions.delete_user_session_token(session_token)
    end

    json(conn, %{ok: true})
  end

  operation :play_token,
    summary: "Create a PlayToken",
    description: """
    PlayTokens only work for streaming audio to allow authentication for audio
    players where you can't override the request headers. In most cases I would
    try to stick to regular authentication headers, if possible.
    """,
    tags: ["Auth"],
    responses: [
      ok:
        {"Successfully generated a new PlayToken.", "application/json", Schemas.PlayTokenResponse},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error}
    ]

  def play_token(conn, _params) do
    play_token = PlayToken.create(conn)

    json(conn, %{
      ok: true,
      expiresIn: PlayToken.max_age(),
      playToken: play_token
    })
  end

  defp login_error(conn, message) do
    json(conn, %{ok: false, fields: %{password: %{message: message}}})
  end
end
