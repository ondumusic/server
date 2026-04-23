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
    properties: %{
      artists: %Schema{
        type: :array,
        items: MusicBoxWeb.Schemas.Artist,
        required: true
      },
      albums: %Schema{
        type: :array,
        items: MusicBoxWeb.Schemas.Album,
        required: true
      },
      tracks: %Schema{
        type: :array,
        items: MusicBoxWeb.Schemas.Track,
        required: true
      },
      playlists: %Schema{
        type: :array,
        items: MusicBoxWeb.Schemas.Playlist,
        required: true
      },
      playlistItems: %Schema{
        type: :array,
        items: MusicBoxWeb.Schemas.PlaylistItem,
        required: true
      },
      deletions: %Schema{
        type: :array,
        items: MusicBoxWeb.Schemas.SyncDeletion,
        required: true
      },
      cursor: MusicBoxWeb.Schemas.SyncCursor,
      complete: %OpenApiSpex.Schema{
        type: :boolean,
        description: "Indicates whether or not there are more items available to sync.",
        example: true,
        required: true
      }
    },
    required: [
      :artists,
      :albums,
      :tracks,
      :playlists,
      :playlistItems,
      :deletions,
      :cursor,
      :complete
    ]
  })

  def fields,
    do: [:artists, :albums, :tracks, :playlists, :playlistItems, :deletions, :cursor, :complete]
end
