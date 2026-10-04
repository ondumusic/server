defmodule MusicBoxWeb.Schemas.SyncCursor do
  @moduledoc false
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "SyncCursor",
    type: :string,
    format: :base64,
    example: "bm90IGEgcmVhbCBjdXJzb3I=",
    description:
      "Use the cursor in your next request to get changes that happened since this cursor."
  })
end

defmodule MusicBoxWeb.Schemas.SyncDeletion do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "SyncDeletion",
    description: """
    Represents the deletion of an entity.
    """,
    type: :object,
    additionalProperties: false,
    properties: %{
      entityId: %Schema{type: :string, format: :uuid},
      entityType: %Schema{
        type: :string,
        enum: ["artist", "album", "track", "playlist", "playlistItem"]
      }
    },
    required: [:entityId, :entityType]
  })
end

defmodule MusicBoxWeb.Schemas.SyncResponse do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "SyncResponse",
    description: "Contains cursor-paginated results for multiple entities.",
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
        items: MusicBoxWeb.Schemas.FlatTrack
      },
      playlists: %Schema{
        type: :array,
        items: MusicBoxWeb.Schemas.Playlist
      },
      playlistItems: %Schema{
        type: :array,
        items: MusicBoxWeb.Schemas.PlaylistItem
      },
      deletions: %Schema{
        type: :array,
        items: MusicBoxWeb.Schemas.SyncDeletion
      },
      notices: %Schema{
        type: :array,
        items: MusicBoxWeb.Schemas.Notice,
        description: "All active server notices (ignores cursor)."
      },
      cursor: MusicBoxWeb.Schemas.SyncCursor,
      complete: %OpenApiSpex.Schema{
        type: :boolean,
        description: "Indicates whether or not there are more items available to sync.",
        example: true
      }
    },
    required: [
      :artists,
      :albums,
      :tracks,
      :playlists,
      :playlistItems,
      :deletions,
      :notices,
      :cursor,
      :complete
    ]
  })

  def fields,
    do: [
      :artists,
      :albums,
      :tracks,
      :playlists,
      :playlistItems,
      :deletions,
      :notices,
      :cursor,
      :complete
    ]
end
