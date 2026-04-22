defmodule MusicBoxWeb.Schemas.PlaylistItem do
  alias OpenApiSpex.Schema
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "PlaylistItem",
    description: "An item inside a playlist",
    type: :object,
    properties: %{
      __type: %Schema{
        type: :string,
        enum: ["playlistItem"],
        default: "playlistItem",
        description: "Entity type"
      },
      id: MusicBoxWeb.Schemas.PlaylistItemId,
      position: %Schema{
        type: :string,
        example: "a",
        description: "The position of the item in the playlist using fractional indexing."
      },
      playlistId: MusicBoxWeb.Schemas.PlaylistId,
      trackId: MusicBoxWeb.Schemas.TrackId,
      insertedAt: %Schema{type: :string, format: :"date-time"}
    },
    required: [:__type, :id, :position, :playlistId, :trackId, :insertedAt]
  })

  def fields, do: [:__type, :id, :position, :playlistId, :trackId, :insertedAt]
end
