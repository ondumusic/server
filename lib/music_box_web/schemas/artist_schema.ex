defmodule MusicBoxWeb.Schemas.ArtistId do
  @moduledoc false
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "ArtistId",
    type: :string,
    format: :uuid,
    pattern: ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i,
    example: "06e59d90-3e45-4b8f-93e2-8f7907c772cc",
    description: "The UUID for a specific Artist."
  })
end

defmodule MusicBoxWeb.Schemas.Artist do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Artist",
    description: "An artist",
    type: :object,
    properties: %{
      __type: %Schema{
        type: :string,
        enum: ["artist"],
        default: "artist",
        description: "Entity type"
      },
      id: MusicBoxWeb.Schemas.PlaylistId,
      name: %Schema{type: :string, example: "The Beatles"},
      sortName: %Schema{type: :string, example: "Beatles"},
      slug: %Schema{type: :string, example: "the-beatles"},
      albumCount: %Schema{type: :integer, example: 2},
      insertedAt: %Schema{type: :string, format: :"date-time"}
    },
    required: [:__type, :id, :name, :sortName, :slug, :albumCount, :insertedAt]
  })

  def fields, do: [:__type, :id, :name, :sortName, :slug, :albumCount, :insertedAt]
end

defmodule MusicBoxWeb.Schemas.ArtistPage do
  @moduledoc false
  require OpenApiSpex
  alias MusicBoxWeb.Schemas.{Page, Artist}

  OpenApiSpex.schema(Page.of(Artist, __subtype: "artist", title: "ArtistPage"))
end
