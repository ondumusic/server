defmodule MusicBoxWeb.Schemas.Notice do
  @moduledoc false
  require OpenApiSpex
  alias MusicBox.Notices.Notice
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Notice",
    description: """
    A notice from the server, e.g. when the music path is unavailable. Clients
    can show their own text for known codes, `message` is an English fallback
    for codes they don't know.
    """,
    type: :object,
    additionalProperties: false,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      code: %Schema{type: :string, enum: Enum.map(Notice.codes(), &to_string/1)},
      level: %Schema{type: :string, enum: ["info", "warning"]},
      message: %Schema{type: :string, example: "No music was found in the music path."},
      raisedAt: %Schema{type: :string, format: :"date-time"}
    },
    required: [:id, :code, :level, :message, :raisedAt]
  })
end

defmodule MusicBoxWeb.Schemas.Notices do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Notices",
    type: :object,
    additionalProperties: false,
    properties: %{
      notices: %Schema{type: :array, items: MusicBoxWeb.Schemas.Notice}
    },
    required: [:notices]
  })
end
