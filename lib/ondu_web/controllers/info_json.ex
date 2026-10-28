defmodule OnduWeb.InfoJSON do
  use OnduWeb, :json

  alias Ondu.Transcoder.Preset

  def info(%{version: version, api_version: api_version} = assigns) do
    %{
      version: version,
      apiVersion: api_version,
      defaultPreset: to_string(assigns.default_preset.id),
      presets: Enum.map(assigns.presets, &preset/1)
    }
  end

  def preset(%Preset{} = preset) do
    %{
      id: to_string(preset.id),
      name: Preset.name(preset),
      codec: preset.codec,
      container: preset.container,
      mimetype: preset.mimetype,
      extension: preset.ext,
      bitrate: preset.bitrate
    }
  end
end
