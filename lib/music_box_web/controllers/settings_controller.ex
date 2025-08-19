defmodule MusicBoxWeb.SettingsController do
  use MusicBoxWeb, :controller

  alias MusicBox.FileScanner
  alias MusicBox.Settings

  def update(conn, params) do
    settings = Settings.get()

    case Settings.set(settings, params) do
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:result, changeset: changeset)

      {:ok, new_settings} ->
        if settings.music_path !== new_settings.music_path,
          do: FileScanner.scan()

        conn
        |> put_status(:ok)
        |> render(:result, settings: new_settings)
    end
  end
end
