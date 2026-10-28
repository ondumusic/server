defmodule OnduWeb.InfoController do
  use OnduWeb, :controller

  alias Ondu.Transcoder.Preset
  alias OnduWeb.ApiSpec

  operation :info,
    summary: "Server information",
    description: """
    The version can be used to show which version of the server is running, or
    to check if it supports a feature. The API version only changes when the API
    changes in a way that breaks existing clients.
    """,
    tags: ["Info"],
    responses: [
      ok: {"Server information.", "application/json", Schemas.ServerInfo},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error}
    ]

  def info(conn, _params) do
    render(conn, :info,
      version: to_string(Application.spec(:ondu, :vsn)),
      api_version: ApiSpec.api_version(),
      default_preset: Preset.default_preset(),
      presets: Preset.list()
    )
  end
end
