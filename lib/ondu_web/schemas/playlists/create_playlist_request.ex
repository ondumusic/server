defmodule OnduWeb.Schemas.CreatePlaylistRequest do
  @moduledoc false
  alias OnduWeb.Schemas.PlaylistId
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "CreatePlaylistRequest",
    type: :object,
    properties: %{
      name: %Schema{type: :string, minLength: 1},
      isFolder: %Schema{type: :boolean, default: false},
      parentId: PlaylistId
    },
    required: [:name],
    additionalProperties: false
  })
end

defmodule OnduWeb.Schemas.CreatePlaylistError do
  @moduledoc false
  alias OnduWeb.Schemas.ChangesetError
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "CreatePlaylistError",
    description: "A response containing validation errors keyed by field name",
    type: :object,
    properties: %{
      ok: %Schema{type: :boolean, example: false},
      fields: %Schema{
        type: :object,
        description: "Map of field names to their validation errors",
        additionalProperties: ChangesetError,
        example: %{
          "name" => %{"message" => "can't be blank"}
        }
      }
    },
    required: [:fields],
    additionalProperties: false
  })
end
