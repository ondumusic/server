defmodule MusicBoxWeb.UserSocket do
  @moduledoc false

  use Phoenix.Socket

  alias MusicBox.Accounts.User
  alias MusicBox.Sessions
  alias MusicBoxWeb.UserAuth

  channel "library:*", MusicBoxWeb.LibraryChannel

  # The session token is sent as auth token (a header), params would end up in
  # the url which is logged by e.g. reverse proxies.
  @impl true
  def connect(_params, socket, connect_info) do
    with signed_session_token when is_binary(signed_session_token) <- connect_info[:auth_token],
         {:ok, session_token} <- UserAuth.verify_session_token(signed_session_token),
         %User{} = user <- Sessions.get_user_by_session_token(session_token) do
      {:ok, assign(socket, :current_user, user)}
    else
      _ -> :error
    end
  end

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.current_user.id}"
end
