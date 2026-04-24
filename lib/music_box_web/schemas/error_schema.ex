defmodule MusicBoxWeb.Schemas.Error do
  @moduledoc false
  alias OpenApiSpex.Schema
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "Error",
    type: :object,
    additionalProperties: false,
    properties: %{
      error: %Schema{type: :string, example: "Unauthorized"}
    },
    required: [:error]
  })
end
