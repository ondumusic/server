defmodule MusicBoxWeb.UserSocketTest do
  use MusicBox.DataCase, async: true

  import Phoenix.ChannelTest

  alias MusicBoxWeb.UserAuth
  alias MusicBoxWeb.UserSocket

  @endpoint MusicBoxWeb.Endpoint

  setup do
    user = MusicBox.AccountsFixtures.user_fixture()

    conn =
      Phoenix.ConnTest.build_conn()
      |> Map.put(:secret_key_base, @endpoint.config(:secret_key_base))
      |> UserAuth.log_in_user(user)

    %{user: user, token: conn.assigns.signed_session_token}
  end

  test "connects with the session token as auth token", %{user: user, token: token} do
    assert {:ok, socket} = connect(UserSocket, %{}, connect_info: %{auth_token: token})
    assert socket.assigns.current_user.id == user.id
  end

  test "refuses invalid, missing or param session tokens", %{token: token} do
    assert :error = connect(UserSocket, %{"sessionToken" => token})
    assert :error = connect(UserSocket, %{}, connect_info: %{auth_token: "invalid"})
    assert :error = connect(UserSocket, %{})
  end
end
