defmodule MusicBoxWeb.SettingsController do
  use MusicBoxWeb, :controller

  alias MusicBox.Settings

  def update(conn, params) do
    case Settings.set(params) do
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:result, changeset: changeset)

      {:ok, settings} ->
        conn
        |> put_status(:ok)
        |> render(:result, settings: settings)
    end
  end
end
