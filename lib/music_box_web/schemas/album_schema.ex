defmodule MusicBoxWeb.Schemas.AlbumId do
  @moduledoc false
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "AlbumId",
    type: :string,
    format: :uuid,
    example: "7c388624-2362-45e2-ae94-ee9aa7a65cb6",
    description: "The UUID for a specific Album."
  })
end

defmodule MusicBoxWeb.Schemas.Album do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Album",
    description: "An album",
    type: :object,
    properties: %{
      __type: %Schema{
        type: :string,
        enum: ["album"],
        default: "album",
        description: "Entity type"
      },
      id: MusicBoxWeb.Schemas.PlaylistId,
      name: %Schema{type: :string, example: "With the Beatles"},
      sortName: %Schema{type: :string, example: "With the Beatles"},
      slug: %Schema{type: :string, example: "with-the-beatles"},
      artistId: MusicBoxWeb.Schemas.ArtistId,
      artworkUrl: %Schema{
        type: :string,
        example: "https://example.com/artwork/123.jpg",
        nullable: true
      },
      tracks: %Schema{
        type: :array,
        items: MusicBoxWeb.Schemas.Track
      },
      releaseYear: %Schema{type: :integer, example: 2, nullable: true},
      trackCount: %Schema{type: :integer, example: 14},
      insertedAt: %Schema{type: :string, format: :"date-time"}
    },
    required: [
      :__type,
      :id,
      :artistId,
      :name,
      :sortName,
      :slug,
      :artworkUrl,
      :releaseYear,
      :trackCount,
      :insertedAt
    ]
  })

  def fields,
    do: [
      :__type,
      :id,
      :artistId,
      :name,
      :sortName,
      :slug,
      :tracks,
      :artworkUrl,
      :releaseYear,
      :trackCount,
      :insertedAt
    ]
end

defmodule MusicBoxWeb.Schemas.AlbumPage do
  @moduledoc false
  require OpenApiSpex
  alias MusicBoxWeb.Schemas.{Album, Page}

  OpenApiSpex.schema(Page.of(Album, __subtype: "album", title: "AlbumPage"))
end
