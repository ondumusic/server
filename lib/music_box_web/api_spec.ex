defmodule MusicBoxWeb.ApiSpec do
  alias OpenApiSpex.{Components, Info, OpenApi, Paths, Server}
  alias MusicBoxWeb.{Endpoint, Router}
  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [
        Server.from_endpoint(Endpoint)
      ],
      info: %Info{
        title: "MusicBox API",
        version: to_string(Application.spec(:my_app, :vsn))
      },
      components: %Components{
        # securitySchemes: %{"authorization" => %SecurityScheme{type: "http", scheme: "bearer"}}
      },
      paths: Paths.from_router(Router)
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
