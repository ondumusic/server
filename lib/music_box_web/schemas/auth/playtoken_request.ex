defmodule MusicBoxWeb.Schemas.PlayTokenResponse do
  @moduledoc false
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "PlayTokenResponse",
    description:
      "Returns a new `playToken` and `expiresIn` (in seconds) so the client knows when to get a new one.",
    type: :object,
    additionalProperties: false,
    properties: %{
      ok: %Schema{type: :boolean, example: true},
      expiresIn: %Schema{
        type: :integer,
        example: 3600,
        description: "Amount of seconds before this PlayToken will expire."
      },
      playToken: MusicBoxWeb.Schemas.PlayToken
    },
    required: [:ok, :expiresIn, :playToken]
  })
end
