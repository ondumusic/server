defmodule MusicBoxWeb.Schemas.ArtistId do
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "ArtistId",
    type: :string,
    format: :uuid,
    pattern: ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i,
    example: "f47ac10b-58cc-4372-a567-0e02b2c3d479",
    description: "The UUID for a specific Artist."
  })
end
