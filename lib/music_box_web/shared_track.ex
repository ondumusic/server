defmodule MusicBoxWeb.SharedTrack do
  defstruct [:user_id, :track_id]

  alias MusicBox.Accounts.User

  @signing_salt "_musicbox_shared_token"
  @max_age 3600
  def create(%{assigns: %{current_user: %User{id: user_id}}} = conn, track_id) do
    Plug.Crypto.sign(
      conn.secret_key_base,
      @signing_salt,
      %__MODULE__{user_id: user_id, track_id: track_id},
      max_age: 3600
    )
  end

  def verify(conn, token) do
    Plug.Crypto.verify(conn.secret_key_base, @signing_salt, token, max_age: @max_age)
  end
end
