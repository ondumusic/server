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
      },
      defaultPreset: %Schema{
        type: :string,
        example: "default_ogg",
        description: "The preset that will be used when none is specified"
      },
      presets: %Schema{
        type: :array,
        items: OnduWeb.Schemas.TranscodingPreset,
        description: "List of available transcoding presets"
      }
    },
    required: [:version, :apiVersion, :defaultPreset, :presets],
    additionalProperties: false
  })
end

defmodule OnduWeb.Schemas.TranscodingPreset do
  @moduledoc false
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "TranscodingPreset",
    type: :object,
    properties: %{
      id: %Schema{
        type: :string,
        example: "default_ogg",
        description: "The identifier for the preset"
      },
      name: %Schema{
        type: :string,
        example: "Default (192kbps)",
        description: "Display name"
      },
      codec: %Schema{type: :string, example: "opus"},
      container: %Schema{type: :string, example: "ogg"},
      mimetype: %Schema{type: :string, example: "audio/ogg"},
      extension: %Schema{type: :string, example: "opus"},
      bitrate: %Schema{type: :integer, example: 192}
    },
    required: [:id, :name, :codec, :container, :mimetype, :extension, :bitrate],
    additionalProperties: false
  })
end
