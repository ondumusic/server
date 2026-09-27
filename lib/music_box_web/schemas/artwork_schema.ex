defmodule MusicBoxWeb.Schemas.ArtworkImage do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ArtworkImage",
    description: """
    A square version of the album artwork. Artwork is never upscaled so the
    dimensions can be smaller than the maximum size of that version.
    """,
    type: :object,
    additionalProperties: false,
    properties: %{
      url: %Schema{
        type: :string,
        example:
          "https://example.com/artwork/7c388624-2362-45e2-ae94-ee9aa7a65cb6/4f1c2a9d8e7b6c5a/large.jpg"
      },
      width: %Schema{type: :integer, example: 640},
      height: %Schema{type: :integer, example: 640}
    },
    required: [:url, :width, :height]
  })
end
