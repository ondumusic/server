defmodule OnduWeb.Schemas.ServerInfo do
  @moduledoc false
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "ServerInfo",
    type: :object,
    properties: %{
      version: %Schema{type: :string, example: "1.3.0", description: "Version of the server"},
      apiVersion: %Schema{
        type: :integer,
        example: 1,
        description: "Only changes when the API changes in a way that breaks existing clients"
      }
    },
    required: [:version, :apiVersion],
    additionalProperties: false
  })
end
