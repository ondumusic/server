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
  alias MusicBoxWeb.Schemas
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
    artworkUrl: %Schema{
      type: :string,
      example: "https://example.com/artwork/123.jpg",
      nullable: true
    },
    releaseYear: %Schema{type: :integer, example: 2, nullable: true},
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
    :artworkUrl,
    :releaseYear,
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
        items: MusicBoxWeb.Schemas.FlatTrack
      }),
    required: [:tracks | @base_required]
  })
end

defmodule MusicBoxWeb.Schemas.AlbumPage do
  @moduledoc false
  require OpenApiSpex
  alias MusicBoxWeb.Schemas.{Album, Page}

  OpenApiSpex.schema(Page.of(Album, __subtype: "album", title: "AlbumPage"))
end

defmodule MusicBoxWeb.Schemas.FlatAlbum do
  @moduledoc false
  require OpenApiSpex
  alias MusicBoxWeb.Schemas

  OpenApiSpex.schema(%{
    title: "FlatAlbum",
    description: "A flat representation of an album (without its tracks embedded).",
    type: :object,
    additionalProperties: false,
    properties: Schemas.Album.base_properties(),
    required: Schemas.Album.base_required()
  })
end
