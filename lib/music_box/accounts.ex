defmodule MusicBox.Accounts do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias MusicBox.Accounts.User
  alias MusicBox.Repo
  alias MusicBox.Sessions.Session

  @spec has_user?() :: boolean()
  def has_user?, do: Repo.exists?(User)

  @spec get_user_by_username(String.t()) :: User.t() | nil
  def get_user_by_username(username) when is_binary(username) do
    Repo.get_by(User, username: username)
  end

  @spec get_user_by_username_and_password(String.t(), String.t()) :: User.t() | nil
  def get_user_by_username_and_password(username, password)
      when is_binary(username) and is_binary(password) do
    user = Repo.get_by(User, username: username)
    if User.valid_password?(user, password), do: user
  end

  @spec get_user!(Ecto.UUID.t()) :: User.t() | nil
  def get_user!(id), do: Repo.get!(User, id)

  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @spec change_user_registration(User.t(), map()) :: Ecto.Changeset.t()
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false)
  end

  @spec change_user_password(User.t(), map()) :: Ecto.Changeset.t()
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @spec update_user_password(User.t(), map()) :: Repo.result(User.t())
  def update_user_password(user, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password()

    update_password_and_delete_sessions(user, changeset)
  end

  @doc """
  Sets a new random password for the user and logs out all their sessions,
  returns the new password.
  """
  @spec reset_user_password(User.t()) :: {:ok, String.t()} | {:error, Ecto.Changeset.t()}
  def reset_user_password(user) do
    password = 18 |> :crypto.strong_rand_bytes() |> Base.url_encode64()
    attrs = %{password: password, password_confirmation: password}

    with {:ok, _user} <-
           update_password_and_delete_sessions(user, User.password_changeset(user, attrs)),
         do: {:ok, password}
  end

  @dialyzer {:no_opaque, update_password_and_delete_sessions: 2}
  defp update_password_and_delete_sessions(user, changeset) do
    Multi.new()
    |> Multi.update(:user, changeset)
    |> Multi.delete_all(:sessions, Session.by_user_and_contexts_query(user, :all))
    |> Repo.transact()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end
end
