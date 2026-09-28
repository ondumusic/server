defmodule MusicBox.Accounts.User do
  @moduledoc false

  use MusicBox.Schema

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :username, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :current_password, :string, virtual: true, redact: true

    timestamps(type: :utc_datetime)
  end

  @type password_opts :: {:hash_password, boolean()}
  @spec registration_changeset(t(), map(), [password_opts()]) :: Ecto.Changeset.t()
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:username, :password])
    |> validate_required([:username])
    |> validate_length(:username, max: 160)
    |> validate_password(opts)
    |> unsafe_validate_unique(:username, MusicBox.Repo)
    |> unique_constraint(:username)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    |> validate_confirmation(:password, message: "does not match password", required: true)
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> validate_length(:password, max: 72, count: :bytes)
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @spec password_changeset(t(), map(), [password_opts()]) :: Ecto.Changeset.t()
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password", required: true)
    |> validate_password(opts)
  end

  @spec valid_password?(User.t(), String.t()) :: boolean()
  def valid_password?(%User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @spec validate_current_password(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def validate_current_password(changeset) do
    changeset = cast(changeset, changeset.params, [:current_password])
    password = get_field(changeset, :current_password)

    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end
end
