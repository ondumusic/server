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
      position: %Schema{
        type: :string,
        description: "Fractional index position",
        example: "a"
      },
      trackId: TrackId
    }
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
      position: %Schema{
        type: :string,
        description: "Fractional index position",
        example: "a"
      },
      itemId: PlaylistItemId
    }
  })
end

defmodule MusicBoxWeb.Schemas.UpdatePlaylistItemsRequest do
  @moduledoc false
  alias MusicBoxWeb.Schemas.PlaylistItemId
  alias MusicBoxWeb.Schemas.{PositionedItem, PositionedTrack}
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "Update Playlist Items Request",
    type: :object,
    properties: %{
      add: %Schema{type: :array, items: PositionedTrack},
      move: %Schema{type: :array, items: PositionedItem},
      remove: %Schema{type: :array, items: PlaylistItemId}
    },
    required: []
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
      added: %Schema{type: :array, items: PlaylistItem},
      moved: %Schema{type: :array, items: PlaylistItem},
      removed: %Schema{type: :array, items: PlaylistItemId}
    },
    required: []
  })
end

defmodule MusicBoxWeb.Schemas.UpdatePlaylistItemsError do
  @moduledoc false
  alias OpenApiSpex.Schema

  defmodule TooManyOperations do
    require OpenApiSpex
    @moduledoc false

    OpenApiSpex.schema(%{
      title: "TooManyOperationsError",
      type: :object,
      required: [:error],
      properties: %{
        error: %Schema{type: :string, enum: ["too_many_operations"]}
      },
      example: %{"error" => "too_many_operations"}
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
        error: %Schema{type: :string, enum: ["move_remove_conflict"]},
        itemIds: %Schema{type: :array, items: %Schema{type: :string}}
      },
      example: %{"error" => "move_remove_conflict", "itemIds" => ["a1", "b2"]}
    })
  end

  defmodule AddMoveConflict do
    require OpenApiSpex
    @moduledoc false

    OpenApiSpex.schema(%{
      title: "AddMoveConflictError",
      type: :object,
      required: [:error, :positions],
      properties: %{
        error: %Schema{type: :string, enum: ["add_move_conflict"]},
        positions: %Schema{type: :array, items: %Schema{type: :string}}
      },
      example: %{"error" => "add_move_conflict", "positions" => ["a1"]}
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
        error: %Schema{type: :string, enum: ["unknown_items"]},
        itemIds: %Schema{type: :array, items: %Schema{type: :string}}
      },
      example: %{"error" => "unknown_items", "itemIds" => ["x9"]}
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
        error: %Schema{type: :string, enum: ["unknown_tracks"]},
        trackIds: %Schema{type: :array, items: %Schema{type: :string}}
      },
      example: %{"error" => "unknown_tracks", "trackIds" => ["t3"]}
    })
  end

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "UpdatePlaylistItemsError",
    description: "Error response returned. The shape depends on `error`.",
    oneOf: [
      TooManyOperations,
      MoveRemoveConflict,
      AddMoveConflict,
      UnknownItems,
      UnknownTracks
    ],
    discriminator: %OpenApiSpex.Discriminator{
      propertyName: "error",
      mapping: %{
        "too_many_operations" => "#/components/schemas/TooManyOperationsError",
        "move_remove_conflict" => "#/components/schemas/MoveRemoveConflictError",
        "add_move_conflict" => "#/components/schemas/AddMoveConflictError",
        "unknown_items" => "#/components/schemas/UnknownItemsError",
        "unknown_tracks" => "#/components/schemas/UnknownTracksError"
      }
    }
  })
end
