defmodule MusicBoxWeb.UserAuth do
  use MusicBoxWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias MusicBox.Sessions

  @max_age 60 * 60 * 24 * 60
  @signing_salt "_musicbox_session_token"

  def log_in_user(conn, current_user) do
    session_token = Sessions.generate_user_session_token(current_user)

    signed_session_token =
      conn.secret_key_base
      |> Plug.Crypto.sign(@signing_salt, session_token, max_age: @max_age)
      |> Base.encode64(padding: false)

    conn
    |> assign(:signed_session_token, signed_session_token)
    |> assign(:session_token, session_token)
    |> assign(:current_user, current_user)
  end

  def log_out_user(conn) do
    {session_token, conn} = ensure_session_token(conn)
    session_token && Sessions.delete_user_session_token(session_token)
    new_assigns = Map.drop(conn.assigns, [:current_user, :session_token, :signed_session_token])
    %{conn | assigns: new_assigns}
  end

  def fetch_current_user(conn, _opts) do
    {session_token, conn} = ensure_session_token(conn)
    current_user = session_token && Sessions.get_user_by_session_token(session_token)
    assign(conn, :current_user, current_user)
  end

  defp ensure_session_token(%{assigns: %{session_token: session_token}} = conn),
    do: {session_token, conn}

  defp ensure_session_token(conn) do
    signed_session_token =
      conn
      |> get_req_header("authorization")
      |> Enum.map(&String.split(&1, " "))
      |> Enum.map(fn
        [bearer, token] -> if(String.downcase(bearer) == "bearer", do: token)
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)
      |> List.first()

    with true <- is_binary(signed_session_token),
         {:ok, signed_session_token} <- Base.decode64(signed_session_token, padding: false),
         {:ok, session_token} <-
           Plug.Crypto.verify(conn.secret_key_base, @signing_salt, signed_session_token,
             max_age: @max_age
           ) do
      {session_token,
       conn
       |> assign(:session_token, session_token)
       |> assign(:signed_session_token, signed_session_token)}
    else
      _ -> {nil, conn}
    end
  end

  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "NOT AUTHENTICATED"})
      |> halt()
    end
  end
end
