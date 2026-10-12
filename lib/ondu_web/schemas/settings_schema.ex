defmodule OnduWeb.Schemas.Settings do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Settings",
    description: "Application settings",
    type: :object,
    additionalProperties: false,
    properties: %{
      musicPath: %Schema{type: :string, example: "/music"},
      scanType: %Schema{type: :string, enum: ["full", "quick"]},
      stripSortPrefixes: %Schema{
        type: :array,
        items: %Schema{
          type: :string
        }
      },
      pollInterval: %Schema{
        type: :integer,
        example: 60,
        description: "How many minutes between scanning the library."
      }
    },
    required: [:musicPath, :scanType, :stripSortPrefixes, :pollInterval]
  })

  def fields, do: [:musicPath, :scanType, :stripSortPrefixes, :pollInterval]
end
