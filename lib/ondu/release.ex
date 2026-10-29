defmodule Ondu.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :ondu

  alias Ondu.Accounts
  alias Ondu.Accounts.User
  alias Ondu.Repo
  alias Ondu.Transcoder

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
      Ecto.Migrator.with_repo(Repo, fn _repo ->
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

  @doc """
  Starts transcoding all music files for the given preset.
  """
  def prewarm_transcode_cache(preset) do
    load_app()
    preset = Transcoder.Preset.get(preset)

    if is_nil(preset) do
      IO.puts(:stderr, "There is no preset with identifier #{preset}")
      System.halt(1)
    end

    # In eval mode the Transcoder has not started so we need to do that as well
    case Transcoder.start_link([]) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    Ecto.Migrator.with_repo(Repo, fn _repo ->
      prewarm_all(preset)
    end)
  end

  defp prewarm_all(preset) do
    import Ecto.Query

    # Figure out which files need to be prewarmed
    files = Repo.all(from f in Ondu.Files.File, join: t in assoc(f, :track), order_by: f.path)
    todo = Enum.reject(files, &match?(%{persisted: true}, Transcoder.get_meta(&1, preset)))
    IO.puts("#{length(todo)} of #{length(files)} files to transcode")

    todo
    |> Enum.with_index(1)
    |> Enum.each(fn {file, i} ->
      case prewarm(file, preset) do
        {:ok, _} -> IO.puts("#{i}/#{length(todo)} started #{file.path}")
        {:error, reason} -> IO.puts("#{i}/#{length(todo)} #{reason} #{file.path}")
      end
    end)
  end

  defp prewarm(file, preset) do
    case Transcoder.request_chunk(file, preset, 0) do
      {:error, :server_busy} ->
        Process.sleep(5_000)
        prewarm(file, preset)

      result ->
        result
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
