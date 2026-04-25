defmodule MusicBoxWeb.Schemas.LogoutResponse do
  @moduledoc false
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "LogoutResponse",
    description: "Successfully revoked `sessionToken`.",
    type: :object,
    additionalProperties: false,
    properties: %{
      ok: %Schema{type: :boolean, example: true}
    },
    required: [:ok]
  })
end
