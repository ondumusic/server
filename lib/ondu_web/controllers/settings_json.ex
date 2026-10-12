defmodule OnduWeb.SettingsJSON do
  use OnduWeb, :json

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
      musicPath: settings.music_path,
      scanType: settings.scan_type,
      stripSortPrefixes: settings.strip_sort_prefixes,
      pollInterval: settings.poll_interval
    }
  end
end
