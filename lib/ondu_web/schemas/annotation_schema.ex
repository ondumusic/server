defmodule OnduWeb.Schemas.Annotation do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Annotation",
    type: :object,
    additionalProperties: false,
    properties: %{
      entityId: %Schema{type: :string, format: :uuid},
      data: %Schema{type: :object, additionalProperties: true, example: %{"mbid" => "..."}},
      updatedAt: %Schema{type: :string, format: :"date-time"}
    },
    required: [:entityId, :data, :updatedAt]
  })
end

defmodule OnduWeb.Schemas.AnnotationPage do
  @moduledoc false
  require OpenApiSpex
  alias OnduWeb.Schemas.{Annotation, Page}

  OpenApiSpex.schema(Page.of(Annotation, __subtype: "annotation", title: "AnnotationPage"))
end

defmodule OnduWeb.Schemas.PutAnnotationsRequest do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "PutAnnotationsRequest",
    type: :object,
    additionalProperties: false,
    properties: %{
      entries: %Schema{
        type: :array,
        maxItems: 500,
        items: %Schema{
          type: :object,
          additionalProperties: false,
          properties: %{
            entityId: %Schema{type: :string, format: :uuid},
            data: %Schema{
              type: :object,
              additionalProperties: true,
              nullable: true,
              description: "Replaces the data (at most 4KB as JSON), null removes the annotation."
            }
          },
          required: [:entityId, :data]
        }
      }
    },
    required: [:entries]
  })
end

defmodule OnduWeb.Schemas.PutAnnotationsResponse do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "PutAnnotationsResponse",
    type: :object,
    additionalProperties: false,
    properties: %{
      ok: %Schema{type: :boolean, example: true},
      skipped: %Schema{
        type: :array,
        items: %Schema{type: :string, format: :uuid},
        description: "Entities that don't exist, so these entries were skipped."
      }
    },
    required: [:ok, :skipped]
  })
end
