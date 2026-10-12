defmodule Ondu.SessionsTest do
  use Ondu.DataCase

  alias Ondu.Sessions

  import Ondu.AccountsFixtures
  alias Ondu.Sessions.Session

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Sessions.generate_user_session_token(user)
      assert user_token = Repo.get_by(Session, token: token)
      assert user_token.context == "session"

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%Session{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Sessions.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert session_user = Sessions.get_user_by_session_token(token)
      assert session_user.id == user.id
    end

    test "does not return user for invalid token" do
      refute Sessions.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(Session, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Sessions.get_user_by_session_token(token)
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Sessions.generate_user_session_token(user)
      assert Sessions.delete_user_session_token(token) == :ok
      refute Sessions.get_user_by_session_token(token)
    end
  end
end
