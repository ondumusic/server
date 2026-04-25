defmodule MusicBoxWeb.Schemas.SearchResults do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "SearchResults",
    description: "Returns the top matching artists, albums and tracks.",
    type: :object,
    additionalProperties: false,
    properties: %{
      artists: %Schema{
        type: :array,
        items: MusicBoxWeb.Schemas.Artist
      },
      albums: %Schema{
        type: :array,
        items: MusicBoxWeb.Schemas.FlatAlbum
      },
      tracks: %Schema{
        type: :array,
        items: MusicBoxWeb.Schemas.Track
      }
    },
    required: [:artists, :albums, :tracks]
  })

  def fields, do: [:artists, :albums, :tracks]
end
