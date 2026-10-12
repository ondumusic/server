defmodule OnduWeb.Schemas.ArtistId do
  @moduledoc false
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "ArtistId",
    type: :string,
    format: :uuid,
    example: "06e59d90-3e45-4b8f-93e2-8f7907c772cc",
    description: "The UUID for a specific Artist."
  })
end

defmodule OnduWeb.Schemas.Artist do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Artist",
    description: "An artist",
    type: :object,
    additionalProperties: false,
    properties: %{
      __type: %Schema{
        type: :string,
        enum: ["artist"],
        default: "artist",
        description: "Entity type"
      },
      id: OnduWeb.Schemas.ArtistId,
      name: %Schema{type: :string, example: "The Beatles"},
      sortName: %Schema{type: :string, example: "Beatles"},
      slug: %Schema{type: :string, example: "the-beatles"},
      albumCount: %Schema{type: :integer, example: 2},
      artwork: %Schema{
        type: :array,
        items: OnduWeb.Schemas.ArtworkImage,
        description: "Available variants of the uploaded artwork, empty without artwork."
      },
      insertedAt: %Schema{type: :string, format: :"date-time"}
    },
    required: [:__type, :id, :name, :sortName, :slug, :albumCount, :artwork, :insertedAt]
  })

  def fields, do: [:__type, :id, :name, :sortName, :slug, :albumCount, :artwork, :insertedAt]
end

defmodule OnduWeb.Schemas.ArtistPage do
  @moduledoc false
  require OpenApiSpex
  alias OnduWeb.Schemas.{Artist, Page}

  OpenApiSpex.schema(Page.of(Artist, __subtype: "artist", title: "ArtistPage"))
end
