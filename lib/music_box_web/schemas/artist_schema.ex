defmodule MusicBoxWeb.Schemas.ArtistId do
  @moduledoc false
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "ArtistId",
    type: :string,
    format: :uuid,
    pattern: ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i,
    example: "06e59d90-3e45-4b8f-93e2-8f7907c772cc",
    description: "The UUID for a specific Artist."
  })
end
