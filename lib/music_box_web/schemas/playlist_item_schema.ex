defmodule MusicBoxWeb.Schemas.PlaylistItemId do
  @moduledoc false
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "PlaylistItemId",
    type: :string,
    format: :uuid,
    example: "6d3e0561-6007-4e18-b1cb-2dd2d440272a",
    description: "The UUID for a specific PlaylistItem."
  })
end

defmodule MusicBoxWeb.Schemas.PlaylistItem do
  @moduledoc false
  alias OpenApiSpex.Schema
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "PlaylistItem",
    description: "An item inside a playlist",
    type: :object,
    additionalProperties: false,
    properties: %{
      __type: %Schema{
        type: :string,
        enum: ["playlistItem"],
        default: "playlistItem",
        description: "Entity type"
      },
      id: MusicBoxWeb.Schemas.PlaylistItemId,
      position: MusicBoxWeb.Schemas.FractionalIndex,
      playlistId: MusicBoxWeb.Schemas.PlaylistId,
      trackId: MusicBoxWeb.Schemas.TrackId,
      insertedAt: %Schema{type: :string, format: :"date-time"}
    },
    required: [:__type, :id, :position, :playlistId, :trackId, :insertedAt]
  })

  def fields, do: [:__type, :id, :position, :playlistId, :trackId, :insertedAt]
end

defmodule MusicBoxWeb.Schemas.PlaylistItemPage do
  @moduledoc false
  require OpenApiSpex
  alias MusicBoxWeb.Schemas.{Page, PlaylistItem}

  OpenApiSpex.schema(Page.of(PlaylistItem, __subtype: "playlistItem", title: "PlaylistItemPage"))
end
