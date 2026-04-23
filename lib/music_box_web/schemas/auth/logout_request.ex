defmodule MusicBoxWeb.Schemas.LogoutResponse do
  @moduledoc false
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "LogoutResponse",
    description: "",
    type: :object,
    properties: %{
      ok: %Schema{type: :boolean, example: "true"}
    },
    required: [:ok]
  })
end
