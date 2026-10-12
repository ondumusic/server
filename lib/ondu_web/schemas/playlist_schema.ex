defmodule OnduWeb.Schemas.PlaylistId do
  @moduledoc false
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "PlaylistId",
    type: :string,
    format: :uuid,
    pattern: ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i,
    example: "c93bfb8e-23fc-41d5-a582-72f823e094d1",
    description: "The UUID for a specific Playlist."
  })
end

defmodule OnduWeb.Schemas.Playlist do
  @moduledoc false
  alias OnduWeb.Schemas.PlaylistId
  alias OpenApiSpex.Schema
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "Playlist",
    description: "A playlist (items not embedded, fetch separately)",
    type: :object,
    additionalProperties: false,
    properties: %{
      __type: %Schema{
        type: :string,
        enum: ["playlist"],
        default: "playlist",
        description: "Entity type"
      },
      id: PlaylistId,
      name: %Schema{type: :string, example: "My Favourite Tracks"},
      isFolder: %Schema{type: :boolean, example: false},
      parentId: %Schema{
        allOf: [PlaylistId],
        nullable: true,
        description: "The parent playlist id (if applicable)"
      },
      trackCount: %Schema{
        type: :integer,
        example: 42,
        description:
          "This contains the amount of tracks inside this playlist. If it is a folder it will always be 0."
      },
      insertedAt: %Schema{type: :string, format: :"date-time"}
    },
    required: [:__type, :id, :name, :isFolder, :parentId, :trackCount, :insertedAt]
  })

  def fields, do: [:__type, :id, :name, :isFolder, :parentId, :trackCount, :insertedAt]
end

defmodule OnduWeb.Schemas.PlaylistPage do
  @moduledoc false
  require OpenApiSpex
  alias OnduWeb.Schemas.{Page, Playlist}

  OpenApiSpex.schema(Page.of(Playlist, __subtype: "playlist", title: "PlaylistPage"))
end
