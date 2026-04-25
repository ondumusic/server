defmodule MusicBoxWeb.Schemas.UpdatePlaylistRequest do
  @moduledoc false
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "UpdatePlaylistRequest",
    type: :object,
    properties: %{
      name: %Schema{type: :string, minLength: 1}
    },
    required: [:name],
    additionalProperties: false
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
