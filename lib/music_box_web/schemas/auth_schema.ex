defmodule MusicBoxWeb.Schemas.UserId do
  @moduledoc false
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "UserId",
    type: :string,
    format: :uuid,
    example: "52745d24-8c68-4550-b217-ce65440df47b",
    description: "The UUID for a specific User."
  })
end

defmodule MusicBoxWeb.Schemas.User do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "User",
    type: :object,
    properties: %{
      id: MusicBoxWeb.Schemas.UserId,
      username: %Schema{type: :string, example: "admin"}
    },
    required: [:id, :username]
  })
end

defmodule MusicBoxWeb.Schemas.SessionToken do
  @moduledoc false
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "SessionToken",
    type: :string,
    format: :base64,
    example: "U2Vzc2lvblRva2Vu"
  })
end

defmodule MusicBoxWeb.Schemas.PlayToken do
  @moduledoc false
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "PlayToken",
    type: :string,
    format: :base64,
    example: "UGxheVRva2Vu"
  })
end

# SignupError
#   ok: false,
#   fields: json_changeset(changeset)

# LogoutResponse
#   ok: true

# PlayTokenResponse
#   ok: true
#   playToken: PlayToken
