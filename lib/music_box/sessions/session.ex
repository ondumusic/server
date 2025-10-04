defmodule MusicBox.Sessions.Session do
  @moduledoc false

  use MusicBox.Schema

  alias MusicBox.Accounts.User

  @session_validity_in_days 60
  @rand_size 32

  @type t :: %__MODULE__{}
  @type token :: binary()
  @type context :: String.t() | :all

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_sessions" do
    field :token, :binary
    field :context, :string
    belongs_to :user, User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @spec build_session_token(User.t()) :: {binary(), t()}
  def build_session_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)
    {token, %Session{token: token, context: "session", user_id: user.id}}
  end

  @spec verify_session_token_query(binary()) :: {:ok, Ecto.Queryable.t()}
  def verify_session_token_query(token) do
    query =
      from(token in by_token_and_context_query(token, "session"),
        join: user in assoc(token, :user),
        where: token.inserted_at > ago(@session_validity_in_days, "day"),
        select: user
      )

    {:ok, query}
  end

  @spec by_token_and_context_query(binary(), context()) :: Ecto.Queryable.t()
  def by_token_and_context_query(token, context) do
    from(Session, where: [token: ^token, context: ^context])
  end

  @spec by_user_and_contexts_query(User.t(), context()) :: Ecto.Queryable.t()
  def by_user_and_contexts_query(user, :all) do
    from(t in Session, where: t.user_id == ^user.id)
  end

  @spec by_user_and_contexts_query(User.t(), [context()]) :: Ecto.Queryable.t()
  def by_user_and_contexts_query(user, [_ | _] = contexts) do
    from(t in Session, where: t.user_id == ^user.id and t.context in ^contexts)
  end
end
