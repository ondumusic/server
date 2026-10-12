defmodule Ondu.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :ondu

  alias Ondu.Accounts
  alias Ondu.Accounts.User

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  Sets a new random password for the given user and prints it, all sessions of
  the user are logged out.
  """
  def reset_password(username) do
    load_app()
    Application.ensure_all_started(:bcrypt_elixir)

    {:ok, result, _} =
      Ecto.Migrator.with_repo(Ondu.Repo, fn _repo ->
        with %User{} = user <- Accounts.get_user_by_username(username),
             do: Accounts.reset_user_password(user)
      end)

    case result do
      {:ok, password} ->
        IO.puts("The new password of #{username} is: #{password}")

      nil ->
        IO.puts(:stderr, "There is no user with username #{username}")
        System.halt(1)

      {:error, changeset} ->
        IO.puts(:stderr, "Failed to reset the password: #{inspect(changeset.errors)}")
        System.halt(1)
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # Many platforms require SSL when connecting to the database
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
