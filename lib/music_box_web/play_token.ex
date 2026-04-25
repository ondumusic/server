defmodule MusicBoxWeb.PlayToken do
  @moduledoc false

  defstruct [:user_id]

  alias MusicBox.Accounts.User

  @signing_salt "_music_box_play_token"
  @max_age 3600
  def create(%{assigns: %{current_user: %User{id: user_id}}} = conn) do
    Plug.Crypto.sign(
      conn.secret_key_base,
      @signing_salt,
      %__MODULE__{user_id: user_id},
      max_age: @max_age
    )
  end

  def verify(conn, token) do
    Plug.Crypto.verify(conn.secret_key_base, @signing_salt, token, max_age: @max_age)
  end

  def max_age, do: @max_age
end
