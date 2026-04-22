defmodule MusicBoxWeb.Schemas.CreatePlaylistRequest do
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "Create Playlist Request",
    type: :object,
    properties: %{
      name: %Schema{type: :string, minLength: 1}
    },
    required: [:name]
  })
end

defmodule MusicBoxWeb.Schemas.CreatePlaylistError do
  alias MusicBoxWeb.Schemas.ChangesetError
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "CreatePlaylistError",
    description: "A response containing validation errors keyed by field name",
    type: :object,
    properties: %{
      fields: %Schema{
        type: :object,
        description: "Map of field names to their validation errors",
        additionalProperties: ChangesetError,
        example: %{
          "name" => %{"message" => "can't be blank"}
        }
      }
    },
    required: [:fields]
  })
end
