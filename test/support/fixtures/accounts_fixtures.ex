defmodule MusicBox.AccountsFixtures do
  def unique_username, do: "user-#{System.unique_integer()}"
  def valid_user_password, do: "itsamemario!"

  def valid_user_attributes(attrs \\ %{}) do
    password = valid_user_password()

    Enum.into(attrs, %{
      username: unique_username(),
      password: password,
      password_confirmation: password
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> MusicBox.Accounts.register_user()

    user
  end
end
