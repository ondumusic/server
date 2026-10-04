defmodule MusicBoxWeb.LibraryChannelTest do
  use MusicBox.DataCase, async: false

  import Phoenix.ChannelTest

  alias MusicBox.Sessions
  alias MusicBoxWeb.{LibraryChannel, UserAuth, UserSocket}

  @endpoint MusicBoxWeb.Endpoint

  setup do
    user = MusicBox.AccountsFixtures.user_fixture()

    conn =
      Phoenix.ConnTest.build_conn()
      |> Map.put(:secret_key_base, @endpoint.config(:secret_key_base))
      |> UserAuth.log_in_user(user)

    {:ok, socket} =
      connect(UserSocket, %{}, connect_info: %{auth_token: conn.assigns.signed_session_token})

    {:ok, _reply, socket} = subscribe_and_join(socket, LibraryChannel, "library:sync")
    @endpoint.subscribe(socket.id)

    %{socket: socket, session_token: conn.assigns.session_token}
  end

  test "pushes library changes" do
    @endpoint.broadcast!("library:sync", "completed", %{})

    assert_push "completed", %{}
    refute_receive %Phoenix.Socket.Broadcast{event: "disconnect"}
  end

  test "disconnects instead of pushing once the session was logged out", %{
    socket: socket,
    session_token: session_token
  } do
    Sessions.delete_user_session_token(session_token)
    @endpoint.broadcast!("library:sync", "completed", %{})

    refute_push "completed", %{}
    topic = socket.id
    assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "disconnect"}
  end

  test "pushes the active notices when they change" do
    {:ok, notice} = MusicBox.Notices.raise_notice(:library_unavailable)
    id = notice.id

    assert_push "notices", %{notices: [%{id: ^id, code: :library_unavailable}]}

    MusicBox.Notices.resolve_notice(:library_unavailable)
    assert_push "notices", %{notices: []}
  end
end
