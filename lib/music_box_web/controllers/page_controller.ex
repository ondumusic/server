defmodule MusicBoxWeb.PageController do
  use MusicBoxWeb, :controller

  alias MusicBox.{Accounts, Settings}

  operation :react, false

  # Tanstack router handles trailing slashes differently which can cause issues
  # so for direct requests we'll just rewrite those as needed.
  def react(%{request_path: path, query_string: query} = conn, _params)
      when binary_part(path, byte_size(path), -1) == "/" and path != "/" do
    target =
      case query do
        "" -> String.trim_trailing(path, "/")
        q -> String.trim_trailing(path, "/") <> "?" <> q
      end

    conn
    |> redirect(to: target)
    |> halt()
  end

  def react(conn, _params) do
    settings = Settings.get()

    has_user? = Accounts.has_user?()
    has_music_path? = not is_nil(settings.music_path)

    onboarding_step = nil

    onboarding_step =
      if not has_user? and is_nil(onboarding_step),
        do: "user",
        else: onboarding_step

    onboarding_step =
      if not has_music_path? and is_nil(onboarding_step),
        do: "settings",
        else: onboarding_step

    hydrate = %{
      onboarding: onboarding_step
    }

    http_status =
      if is_nil(onboarding_step),
        do: :ok,
        else: :failed_dependency

    conn
    |> put_status(http_status)
    |> render(:react, hydrate: hydrate)
  end

  operation :docs, false

  def docs(conn, _params) do
    conn
    |> put_root_layout(false)
    |> render(:docs, layout: false)
  end
end
