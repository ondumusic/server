defmodule MusicBoxWeb.Schemas.PositionedTrack do
  @moduledoc false
  alias MusicBoxWeb.Schemas.TrackId
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "PositionedTrack",
    type: :object,
    required: [:position, :trackId],
    properties: %{
      position: MusicBoxWeb.Schemas.FractionalIndex,
      trackId: TrackId
    },
    additionalProperties: false
  })
end

defmodule MusicBoxWeb.Schemas.PositionedItem do
  @moduledoc false
  alias MusicBoxWeb.Schemas.PlaylistItemId
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "PositionedItem",
    type: :object,
    required: [:position, :itemId],
    properties: %{
      position: MusicBoxWeb.Schemas.FractionalIndex,
      itemId: PlaylistItemId
    },
    additionalProperties: false
  })
end

defmodule MusicBoxWeb.Schemas.UpdatePlaylistItemsRequest do
  @moduledoc false
  alias MusicBoxWeb.Schemas.PlaylistItemId
  alias MusicBoxWeb.Schemas.{PositionedItem, PositionedTrack}
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "UpdatePlaylistItemsRequest",
    type: :object,
    properties: %{
      add: %Schema{type: :array, items: PositionedTrack},
      move: %Schema{type: :array, items: PositionedItem},
      remove: %Schema{type: :array, items: PlaylistItemId}
    },
    required: [],
    additionalProperties: false
  })
end

defmodule MusicBoxWeb.Schemas.UpdatePlaylistItemsResponse do
  @moduledoc false
  alias MusicBoxWeb.Schemas.{PlaylistItem, PlaylistItemId}
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "UpdatePlaylistItemsResponse",
    type: :object,
    properties: %{
      ok: %Schema{type: :boolean, example: true},
      added: %Schema{type: :array, items: PlaylistItem},
      moved: %Schema{type: :array, items: PlaylistItem},
      removed: %Schema{type: :array, items: PlaylistItemId}
    },
    required: [:ok, :added, :moved, :removed],
    additionalProperties: false
  })
end

defmodule MusicBoxWeb.Schemas.UpdatePlaylistItemsError do
  @moduledoc false
  alias OpenApiSpex.Schema

  defmodule PlaylistIsFolder do
    require OpenApiSpex
    @moduledoc false

    OpenApiSpex.schema(%{
      title: "PlaylistIsFolderError",
      type: :object,
      required: [:error],
      properties: %{
        ok: %Schema{type: :boolean, example: false},
        error: %Schema{type: :string, enum: ["playlist_is_folder"]}
      },
      example: %{"error" => "playlist_is_folder"},
      additionalProperties: false
    })
  end

  defmodule TooManyOperations do
    require OpenApiSpex
    @moduledoc false

    OpenApiSpex.schema(%{
      title: "TooManyOperationsError",
      type: :object,
      required: [:error],
      properties: %{
        ok: %Schema{type: :boolean, example: false},
        error: %Schema{type: :string, enum: ["too_many_operations"]},
        limit: %Schema{type: :integer, example: 100},
        count: %Schema{type: :integer, example: 150}
      },
      example: %{"error" => "too_many_operations"},
      additionalProperties: false
    })
  end

  defmodule MoveRemoveConflict do
    require OpenApiSpex
    @moduledoc false

    OpenApiSpex.schema(%{
      title: "MoveRemoveConflictError",
      type: :object,
      required: [:error, :itemIds],
      properties: %{
        ok: %Schema{type: :boolean, example: false},
        error: %Schema{type: :string, enum: ["move_remove_conflict"]},
        itemIds: %Schema{type: :array, items: %Schema{type: :string}}
      },
      example: %{"error" => "move_remove_conflict", "itemIds" => ["a1", "b2"]},
      additionalProperties: false
    })
  end

  defmodule DuplicateItems do
    require OpenApiSpex
    @moduledoc false

    OpenApiSpex.schema(%{
      title: "DuplicateItemsError",
      description: "The same item is moved, or removed, more than once.",
      type: :object,
      required: [:error, :itemIds],
      properties: %{
        ok: %Schema{type: :boolean, example: false},
        error: %Schema{type: :string, enum: ["duplicate_items"]},
        itemIds: %Schema{type: :array, items: %Schema{type: :string}}
      },
      example: %{"error" => "duplicate_items", "itemIds" => ["a1"]},
      additionalProperties: false
    })
  end

  defmodule InvalidPositions do
    require OpenApiSpex
    @moduledoc false

    OpenApiSpex.schema(%{
      title: "InvalidPositionsError",
      type: :object,
      required: [:error, :positions],
      properties: %{
        ok: %Schema{type: :boolean, example: false},
        error: %Schema{type: :string, enum: ["invalid_positions"]},
        positions: %Schema{type: :array, items: %Schema{type: :string}}
      },
      example: %{"error" => "invalid_positions", "positions" => ["z@p"]},
      additionalProperties: false
    })
  end

  defmodule UnknownItems do
    require OpenApiSpex
    @moduledoc false

    OpenApiSpex.schema(%{
      title: "UnknownItemsError",
      type: :object,
      required: [:error, :itemIds],
      properties: %{
        ok: %Schema{type: :boolean, example: false},
        error: %Schema{type: :string, enum: ["unknown_items"]},
        itemIds: %Schema{type: :array, items: %Schema{type: :string}}
      },
      example: %{"error" => "unknown_items", "itemIds" => ["x9"]},
      additionalProperties: false
    })
  end

  defmodule UnknownTracks do
    require OpenApiSpex
    @moduledoc false

    OpenApiSpex.schema(%{
      title: "UnknownTracksError",
      type: :object,
      required: [:error, :trackIds],
      properties: %{
        ok: %Schema{type: :boolean, example: false},
        error: %Schema{type: :string, enum: ["unknown_tracks"]},
        trackIds: %Schema{type: :array, items: %Schema{type: :string}}
      },
      example: %{"error" => "unknown_tracks", "trackIds" => ["t3"]},
      additionalProperties: false
    })
  end

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "UpdatePlaylistItemsError",
    description: "Error response returned. The shape depends on `error`.",
    oneOf: [
      PlaylistIsFolder,
      TooManyOperations,
      MoveRemoveConflict,
      DuplicateItems,
      InvalidPositions,
      UnknownItems,
      UnknownTracks
    ],
    discriminator: %OpenApiSpex.Discriminator{
      propertyName: "error",
      mapping: %{
        "playlist_is_folder" => "#/components/schemas/PlaylistIsFolderError",
        "too_many_operations" => "#/components/schemas/TooManyOperationsError",
        "move_remove_conflict" => "#/components/schemas/MoveRemoveConflictError",
        "duplicate_items" => "#/components/schemas/DuplicateItemsError",
        "invalid_positions" => "#/components/schemas/InvalidPositionsError",
        "unknown_items" => "#/components/schemas/UnknownItemsError",
        "unknown_tracks" => "#/components/schemas/UnknownTracksError"
      }
    },
    additionalProperties: false
  })
end
