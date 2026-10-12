defmodule OnduWeb.Schemas.TrackId do
  @moduledoc false
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "TrackId",
    type: :string,
    format: :uuid,
    example: "52cf997e-3acc-414e-b92c-4f32895a41d9",
    description: "The UUID for a specific Track."
  })
end

defmodule OnduWeb.Schemas.Track do
  @moduledoc false
  require OpenApiSpex
  alias OnduWeb.Schemas
  alias OpenApiSpex.Schema

  @base_properties %{
    __type: %Schema{
      type: :string,
      enum: ["track"],
      default: "track",
      description: "Entity type"
    },
    id: Schemas.TrackId,
    artistId: Schemas.ArtistId,
    albumArtistId: Schemas.ArtistId,
    albumId: Schemas.AlbumId,
    name: %Schema{type: :string, example: "The Beatles"},
    disc: %Schema{type: :integer, example: 1, nullable: true},
    number: %Schema{type: :integer, example: 1, nullable: true},
    duration: %Schema{type: :number, example: 123.45},
    loudness: %Schema{
      allOf: [Schemas.Loudness],
      nullable: true,
      description: "The measured loudness, null until measured (or when measuring failed)"
    },
    playCount: %Schema{type: :integer, example: 3, description: "How often it was played"},
    lastPlayedAt: %Schema{
      type: :string,
      format: :"date-time",
      nullable: true,
      description: "When it was last played, null when never played"
    },
    mimetype: %Schema{type: :string, example: "audio/mp3"},
    downloadUrl: %Schema{type: :string, example: "https://example.com/download/..."},
    streamUrl: %Schema{type: :string, example: "https://example.com/stream/..."},
    insertedAt: %Schema{type: :string, format: :"date-time"},
    relativeFilePath: %Schema{
      type: :string,
      example: "The Beatles/Revolver/01 Taxman.m4a",
      description: """
      This is the relative file path of this track inside your library.
      """
    }
  }

  @base_required [
    :__type,
    :id,
    :artistId,
    :albumArtistId,
    :albumId,
    :name,
    :disc,
    :number,
    :duration,
    :loudness,
    :playCount,
    :lastPlayedAt,
    :mimetype,
    :downloadUrl,
    :streamUrl,
    :insertedAt
  ]

  def base_properties, do: @base_properties
  def base_required, do: @base_required

  OpenApiSpex.schema(%{
    title: "Track",
    description: "A track with its artist and album embedded",
    type: :object,
    additionalProperties: false,
    properties:
      @base_properties
      |> Map.put(:artist, OnduWeb.Schemas.Artist)
      |> Map.put(:album, OnduWeb.Schemas.FlatAlbum),
    required: [:artist, :album | @base_required]
  })
end

defmodule OnduWeb.Schemas.TrackPage do
  @moduledoc false
  require OpenApiSpex
  alias OnduWeb.Schemas.{Page, Track}

  OpenApiSpex.schema(Page.of(Track, __subtype: "track", title: "TrackPage"))
end

defmodule OnduWeb.Schemas.FlatTrack do
  @moduledoc false
  require OpenApiSpex
  alias OnduWeb.Schemas

  OpenApiSpex.schema(%{
    title: "FlatTrack",
    description: "A flat representation of a track (without its artist/album embedded).",
    type: :object,
    additionalProperties: false,
    properties: Schemas.Track.base_properties(),
    required: Schemas.Track.base_required()
  })
end
