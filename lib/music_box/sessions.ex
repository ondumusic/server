defmodule MusicBox.Sessions do
  import Ecto.Query, warn: false

  alias MusicBox.Repo
  alias MusicBox.Sessions.Session

  def generate_user_session_token(user) do
    {token, user_token} = Session.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  def get_user_by_session_token(token) do
    {:ok, query} = Session.verify_session_token_query(token)
    Repo.one(query)
  end

  def delete_user_session_token(token) do
    Repo.delete_all(Session.by_token_and_context_query(token, "session"))
    :ok
  end
end
