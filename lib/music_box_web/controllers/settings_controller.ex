defmodule MusicBoxWeb.SettingsController do
  use MusicBoxWeb, :controller

  alias MusicBox.FileScanner
  alias MusicBox.Settings

  operation :show,
    summary: "Get library settings",
    tags: ["Settings"],
    responses: [
      ok: {"Returns the current library settings.", "application/json", Schemas.Settings},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error}
    ]

  def show(conn, _params) do
    settings = Settings.get()
    render(conn, :settings, settings: settings)
  end

  operation :update,
    summary: "Update library settings",
    tags: ["Settings"],
    request_body: {"Operations", "application/json", Schemas.UpdateSettingsRequest},
    responses: [
      ok:
        {"Successfully updated the library settings.", "application/json",
         Schemas.UpdateSettingsResponse},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error},
      unprocessable_entity:
        {"Validation failed.", "application/json", Schemas.UpdateSettingsError}
    ]

  def update(conn, params) do
    settings = Settings.get()

    case Settings.set(settings, params) do
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:result, changeset: changeset)

      {:ok, new_settings} ->
        if settings.music_path !== new_settings.music_path,
          do: FileScanner.scan_async(:full)

        conn
        |> put_status(:ok)
        |> render(:result, settings: new_settings)
    end
  end
end
