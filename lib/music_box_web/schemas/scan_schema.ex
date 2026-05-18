defmodule MusicBoxWeb.Schemas.ScanResponse do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ScanResponse",
    description: "Confirms asynchronous file scanner has started.",
    type: :object,
    additionalProperties: false,
    properties: %{
      ok: %Schema{type: :boolean, example: true}
    },
    required: [
      :ok
    ]
  })

  def fields,
    do: [:ok]
end
