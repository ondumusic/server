defmodule MusicBoxWeb.Schemas.UpdatePlaylistRequest do
  @moduledoc false
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "Update Playlist Request",
    type: :object,
    properties: %{
      name: %Schema{type: :string, minLength: 1}
    },
    required: [:name]
  })
end

defmodule MusicBoxWeb.Schemas.UpdatePlaylistError do
  @moduledoc false
  alias MusicBoxWeb.Schemas.ChangesetError
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "UpdatePlaylistError",
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
