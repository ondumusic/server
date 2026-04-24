defmodule MusicBoxWeb.Schemas.PlayTokenResponse do
  @moduledoc false
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "PlayTokenResponse",
    description: "",
    type: :object,
    additionalProperties: false,
    properties: %{
      ok: %Schema{type: :boolean, example: "true"},
      playToken: MusicBoxWeb.Schemas.PlayToken
    },
    required: [:ok, :playToken]
  })
end
