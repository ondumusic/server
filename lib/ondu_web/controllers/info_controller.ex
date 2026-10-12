defmodule OnduWeb.InfoController do
  use OnduWeb, :controller

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
    json(conn, %{
      version: to_string(Application.spec(:ondu, :vsn)),
      apiVersion: ApiSpec.api_version()
    })
  end
end
