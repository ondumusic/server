defmodule MusicBoxWeb.ApiSpec do
  @moduledoc false
  alias MusicBoxWeb.Router
  alias OpenApiSpex.{Components, Info, OpenApi, Paths, SecurityScheme, Server, Tag}
  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [%Server{url: "/"}],
      info: %Info{
        title: "MusicBox API",
        version: to_string(Application.spec(:music_box, :vsn)),
        description: """
        ## Authentication
        All requests require a bearer token in the `Authorization` header,
        however it is also possible to generate a `playToken` that temporarily
        lets you access track downloads/streams. This is mostly intended to be
        used by clients that cannot add the `Authorization` header to their
        audio player requests (like a native `<audio>` tag in HTML).
        """
      },
      tags: [
        %Tag{name: "Artists", description: "Browse artists"},
        %Tag{name: "Albums", description: "Browse albums"},
        %Tag{name: "Tracks", description: "Browse tracks"},
        %Tag{name: "Auth", description: "Authentication and session management"},
        %Tag{name: "Sync", description: "Library synchronization"},
        %Tag{name: "Search", description: "Search across the library"},
        %Tag{name: "Settings", description: "Manage library settings"},
        %Tag{name: "Playlists", description: "Create and manage playlists"}
      ],
      components: %Components{
        securitySchemes: %{
          "sessionToken" => %SecurityScheme{type: "http", scheme: "bearer"},
          "playToken" => %SecurityScheme{type: "apiKey", in: "query", name: "token"}
        }
      },
      security: [%{"sessionToken" => []}],
      paths: Paths.from_router(Router)
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
