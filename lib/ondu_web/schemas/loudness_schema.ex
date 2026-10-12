defmodule OnduWeb.Schemas.Loudness do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Loudness",
    description: """
    The measured loudness of a track or album (ITU-R BS.1770 / EBU R128), clients
    can use this for volume normalization. To normalize to a target loudness apply a gain
    of `target - lufs` dB, and when boosting keep it below `-peak` dB to avoid
    clipping.
    """,
    type: :object,
    additionalProperties: false,
    properties: %{
      lufs: %Schema{
        type: :number,
        example: -9.2,
        description: "Integrated loudness in LUFS"
      },
      peak: %Schema{
        type: :number,
        example: -0.3,
        nullable: true,
        description: "True peak in dBFS, null for digital silence"
      }
    },
    required: [:lufs, :peak]
  })
end
