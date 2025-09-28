defmodule MusicBoxWeb.UserSocket do
  @moduledoc false

  use Phoenix.Socket

  alias MusicBox.Accounts.User
  alias MusicBox.Sessions
  alias MusicBoxWeb.UserAuth

  channel "library:*", MusicBoxWeb.LibraryChannel

  @impl true
  def connect(%{"sessionToken" => signed_session_token}, socket, _connect_info) do
    with {:ok, session_token} <- UserAuth.verify_session_token(signed_session_token),
         %User{} = user <- Sessions.get_user_by_session_token(session_token) do
      {:ok, assign(socket, :current_user, user)}
    else
      _ -> :error
    end
  end

  def connect(_params, _socket, _connect_info),
    do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.current_user.id}"
end
