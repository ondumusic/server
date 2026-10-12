defmodule Ondu.Sessions do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Ondu.Accounts.User
  alias Ondu.Repo
  alias Ondu.Sessions.Session

  @spec generate_user_session_token(User.t()) :: Session.token()
  def generate_user_session_token(user) do
    {token, user_token} = Session.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @spec get_user_by_session_token(Session.token()) :: User.t()
  def get_user_by_session_token(token) do
    {:ok, query} = Session.verify_session_token_query(token)
    Repo.one(query)
  end

  @spec delete_user_session_token(Session.token()) :: :ok
  def delete_user_session_token(token) do
    Repo.delete_all(Session.by_token_and_context_query(token, "session"))
    :ok
  end
end
