defmodule OnduWeb.ApiSpec do
  @moduledoc false
  alias OnduWeb.Router

  alias OpenApiSpex.{
    Components,
    ExternalDocumentation,
    Info,
    OpenApi,
    Paths,
    SecurityScheme,
    Server,
    Tag
  }

  @behaviour OpenApi

  # Only increased when the API changes in a way that breaks existing clients,
  # e.g. removing or renaming fields or endpoints. Additions don't change it.
  @api_version 1

  @spec api_version() :: pos_integer()
  def api_version, do: @api_version

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [%Server{url: "/"}],
      externalDocs: %ExternalDocumentation{
        description: "Setting up Ondu Server",
        url: "https://ondumusic.com/setup.html"
      },
      info: %Info{
        title: "Ondu Server API",
        version: to_string(Application.spec(:ondu, :vsn)),
        description: """
        ## Authentication
        All requests require a bearer token in the `Authorization` header,
        however it is also possible to generate a `playToken` that temporarily
        lets you access track downloads/streams. This is mostly intended to be
        used by clients that cannot add the `Authorization` header to their
        audio player requests (like a native `<audio>` tag in HTML).

        ## Versions
        `GET /api/info` returns the version of the server and of the API. The API
        version only changes when the API changes in a way that breaks existing
        clients, additions (e.g. new endpoints, fields or error codes) do not
        change it. Clients should ignore fields and values they don't know.
        """
      },
      tags: [
        %Tag{name: "Artists", description: "Browse artists"},
        %Tag{name: "Albums", description: "Browse albums"},
        %Tag{name: "Tracks", description: "Browse tracks"},
        %Tag{name: "Auth", description: "Authentication and session management"},
        %Tag{name: "Info", description: "Server information"},
        %Tag{name: "Notices", description: "Notices from the server"},
        %Tag{name: "Annotations", description: "Annotations for artists, albums"},
        %Tag{name: "Sync", description: "Library synchronization"},
        %Tag{name: "Scan", description: "Library file scanning"},
        %Tag{name: "Search", description: "Search across the library"},
        %Tag{name: "Issues", description: "Find potential issues with library"},
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
