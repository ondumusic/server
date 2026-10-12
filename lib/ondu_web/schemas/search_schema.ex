defmodule OnduWeb.Schemas.SearchResults do
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
        items: OnduWeb.Schemas.Artist
      },
      albums: %Schema{
        type: :array,
        items: OnduWeb.Schemas.FlatAlbum
      },
      tracks: %Schema{
        type: :array,
        items: OnduWeb.Schemas.Track
      }
    },
    required: [:artists, :albums, :tracks]
  })

  def fields, do: [:artists, :albums, :tracks]
end
