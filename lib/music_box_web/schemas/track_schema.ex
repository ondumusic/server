defmodule MusicBoxWeb.Schemas.TrackId do
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

defmodule MusicBoxWeb.Schemas.Track do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Track",
    description: "A track",
    type: :object,
    additionalProperties: false,
    properties: %{
      __type: %Schema{
        type: :string,
        enum: ["track"],
        default: "track",
        description: "Entity type"
      },
      id: MusicBoxWeb.Schemas.PlaylistId,
      artistId: MusicBoxWeb.Schemas.ArtistId,
      artist: MusicBoxWeb.Schemas.Artist,
      albumArtistId: MusicBoxWeb.Schemas.ArtistId,
      albumId: MusicBoxWeb.Schemas.AlbumId,
      album: MusicBoxWeb.Schemas.Album,
      name: %Schema{type: :string, example: "The Beatles"},
      disc: %Schema{type: :integer, example: 1, nullable: true},
      number: %Schema{type: :integer, example: 1, nullable: true},
      duration: %Schema{type: :number, example: 123.45},
      mimetype: %Schema{type: :string, example: "audio/mp3"},
      downloadUrl: %Schema{type: :string, example: "https://example.com/download/..."},
      streamUrl: %Schema{type: :string, example: "https://example.com/stream/..."},
      insertedAt: %Schema{type: :string, format: :"date-time"}
    },
    required: [
      :__type,
      :id,
      :artistId,
      :albumArtistId,
      :albumId,
      :name,
      :disc,
      :number,
      :duration,
      :mimetype,
      :downloadUrl,
      :streamUrl,
      :insertedAt
    ]
  })

  def fields,
    do: [
      :__type,
      :id,
      :artistId,
      :artist,
      :albumArtistId,
      :albumId,
      :album,
      :name,
      :disc,
      :number,
      :duration,
      :mimetype,
      :downloadUrl,
      :streamUrl,
      :insertedAt
    ]
end

defmodule MusicBoxWeb.Schemas.TrackPage do
  @moduledoc false
  require OpenApiSpex
  alias MusicBoxWeb.Schemas.{Page, Track}

  OpenApiSpex.schema(Page.of(Track, __subtype: "track", title: "TrackPage"))
end
