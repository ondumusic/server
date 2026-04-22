defmodule MusicBoxWeb.ApiSpec do
  @moduledoc false
  alias MusicBoxWeb.{Endpoint, Router}
  alias OpenApiSpex.{Components, Info, OpenApi, Paths, Server, Tag}
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
      tags: [
        %Tag{name: "Artists", description: "Artist management"},
        %Tag{name: "Albums", description: "Album management"},
        %Tag{name: "Tracks", description: "Track management"},
        %Tag{name: "Sync", description: "Sync operations"},
        %Tag{name: "Playlists", description: "Playlist management"}
      ],
      components: %Components{
        # securitySchemes: %{"authorization" => %SecurityScheme{type: "http", scheme: "bearer"}}
      },
      paths: Paths.from_router(Router)
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
