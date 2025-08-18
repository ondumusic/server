defmodule MusicBoxWeb.SettingsJSON do
  use MusicBoxWeb, :json

  def result(%{changeset: changeset}) do
    %{
      ok: false,
      fields: json_changeset(changeset)
    }
  end

  def result(%{settings: settings}) do
    %{
      ok: true,
      settings: settings(%{settings: settings})
    }
  end

  def settings(%{settings: settings}) do
    %{
      music_path: settings.music_path
    }
  end
end
