defmodule OnduWeb.Schemas.UpdateSettingsRequest do
  @moduledoc false
  alias OnduWeb.Schemas.Settings
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "UpdateSettingsRequest",
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
    required: []
  })
end

defmodule OnduWeb.Schemas.UpdateSettingsResponse do
  @moduledoc false
  alias OnduWeb.Schemas.Settings
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "UpdateSettingsResponse",
    type: :object,
    additionalProperties: false,
    properties: %{
      ok: %Schema{type: :boolean, example: true},
      settings: Settings
    },
    required: [:ok, :settings]
  })
end

defmodule OnduWeb.Schemas.UpdateSettingsError do
  @moduledoc false
  alias OnduWeb.Schemas.ChangesetError
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "UpdateSettingsError",
    description: "A response containing validation errors keyed by field name",
    type: :object,
    additionalProperties: false,
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
    required: [:ok, :fields]
  })
end
