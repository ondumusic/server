defmodule MusicBoxWeb.SettingsController do
  use MusicBoxWeb, :controller

  alias MusicBox.FileScanner
  alias MusicBox.Settings

  operation :show,
    summary: "Get current settings",
    tags: ["Settings"],
    responses: [
      ok: {"Settings", "application/json", Schemas.Settings},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]

  def show(conn, _params) do
    settings = Settings.get()
    render(conn, :settings, settings: settings)
  end

  operation :update,
    summary: "Update current settings",
    tags: ["Settings"],
    request_body: {"Operations", "application/json", Schemas.UpdateSettingsRequest},
    responses: [
      ok: {"Settings", "application/json", Schemas.UpdateSettingsResponse},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      bad_request: {"Bad Request", "application/json", Schemas.UpdateSettingsError}
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
