defmodule MusicBoxWeb.Schemas.Playlist do
  alias OpenApiSpex.Schema
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "Playlist",
    description: "A playlist with tracks",
    type: :object,
    properties: %{
      __type: %Schema{
        type: :string,
        enum: ["playlist"],
        default: "playlist",
        description: "Entity type"
      },
      id: MusicBoxWeb.Schemas.PlaylistId,
      name: %Schema{type: :string, example: "My Favourite Tracks"},
      trackCount: %Schema{type: :integer, example: 42},
      insertedAt: %Schema{type: :string, format: :"date-time"}
    },
    required: [:__type, :id, :name, :trackCount, :insertedAt]
  })

  def fields, do: [:__type, :id, :name, :trackCount, :insertedAt]
end
