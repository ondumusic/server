defmodule OnduWeb.UserSocket do
  @moduledoc false

  use Phoenix.Socket

  alias Ondu.Accounts.User
  alias Ondu.Sessions
  alias OnduWeb.UserAuth

  channel "library:*", OnduWeb.LibraryChannel

  # The session token is sent as auth token (a header), params would end up in
  # the url which is logged by e.g. reverse proxies.
  @impl true
  def connect(_params, socket, connect_info) do
    with signed_session_token when is_binary(signed_session_token) <- connect_info[:auth_token],
         {:ok, session_token} <- UserAuth.verify_session_token(signed_session_token),
         %User{} = user <- Sessions.get_user_by_session_token(session_token) do
      {:ok, socket |> assign(:current_user, user) |> assign(:session_token, session_token)}
    else
      _ -> :error
    end
  end

  @impl true
  # One id per session, so the socket of a single session can be disconnected.
  def id(socket) do
    hash = :crypto.hash(:sha256, socket.assigns.session_token)
    "user_socket:" <> Base.url_encode64(hash, padding: false)
  end
end
