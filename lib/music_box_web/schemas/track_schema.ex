defmodule MusicBoxWeb.Schemas.TrackId do
  @moduledoc false
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "TrackId",
    type: :string,
    format: :uuid,
    pattern: ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i,
    example: "52cf997e-3acc-414e-b92c-4f32895a41d9",
    description: "The UUID for a specific Track."
  })
end
