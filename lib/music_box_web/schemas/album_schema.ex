defmodule MusicBoxWeb.Schemas.AlbumId do
  @moduledoc false
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "AlbumId",
    type: :string,
    format: :uuid,
    pattern: ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i,
    example: "7c388624-2362-45e2-ae94-ee9aa7a65cb6",
    description: "The UUID for a specific Album."
  })
end
