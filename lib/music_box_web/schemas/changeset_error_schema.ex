defmodule MusicBoxWeb.Schemas.ChangesetError do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ValidationError",
    description: "A validation error for a single field",
    type: :object,
    additionalProperties: false,
    properties: %{
      message: %Schema{
        type: :string,
        description: "Human-readable error message",
        example: "can't be blank"
      }
    },
    required: [:message]
  })
end
