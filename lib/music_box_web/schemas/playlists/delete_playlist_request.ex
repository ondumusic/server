defmodule MusicBoxWeb.Schemas.DeletePlaylistError do
  alias MusicBoxWeb.Schemas.ChangesetError
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "DeletePlaylistError",
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
