defmodule OnduWeb.Schemas.AlbumId do
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

defmodule OnduWeb.Schemas.Album do
  @moduledoc false
  require OpenApiSpex
  alias OnduWeb.Schemas
  alias OpenApiSpex.Schema

  @base_properties %{
    __type: %Schema{
      type: :string,
      enum: ["album"],
      default: "album",
      description: "Entity type"
    },
    id: Schemas.AlbumId,
    name: %Schema{type: :string, example: "With the Beatles"},
    sortName: %Schema{type: :string, example: "With the Beatles"},
    slug: %Schema{type: :string, example: "with-the-beatles"},
    artistId: Schemas.ArtistId,
    artwork: %Schema{
      type: :array,
      items: Schemas.ArtworkImage,
      description: "Available variants of the artwork."
    },
    releaseYear: %Schema{type: :integer, example: 2, nullable: true},
    loudness: %Schema{
      allOf: [Schemas.Loudness],
      nullable: true,
      description: """
      The loudness of the whole album, to use one gain for all tracks when the
      album is played in sequence. Approximated from the loudness of the tracks,
      null until all tracks are measured.
      """
    },
    trackCount: %Schema{type: :integer, example: 14},
    isUnknown: %Schema{type: :boolean, example: false},
    insertedAt: %Schema{type: :string, format: :"date-time"}
  }

  @base_required [
    :__type,
    :id,
    :artistId,
    :name,
    :sortName,
    :slug,
    :artwork,
    :releaseYear,
    :loudness,
    :trackCount,
    :isUnknown,
    :insertedAt
  ]

  def base_properties, do: @base_properties
  def base_required, do: @base_required

  OpenApiSpex.schema(%{
    title: "Album",
    description: "An album",
    type: :object,
    additionalProperties: false,
    properties:
      Map.put(@base_properties, :tracks, %Schema{
        type: :array,
        items: OnduWeb.Schemas.FlatTrack
      }),
    required: [:tracks | @base_required]
  })
end

defmodule OnduWeb.Schemas.AlbumPage do
  @moduledoc false
  require OpenApiSpex
  alias OnduWeb.Schemas.{Album, Page}

  OpenApiSpex.schema(Page.of(Album, __subtype: "album", title: "AlbumPage"))
end

defmodule OnduWeb.Schemas.FlatAlbum do
  @moduledoc false
  require OpenApiSpex
  alias OnduWeb.Schemas

  OpenApiSpex.schema(%{
    title: "FlatAlbum",
    description: "A flat representation of an album (without its tracks embedded).",
    type: :object,
    additionalProperties: false,
    properties: Schemas.Album.base_properties(),
    required: Schemas.Album.base_required()
  })
end
