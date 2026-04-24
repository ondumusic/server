defmodule MusicBoxWeb.Schemas.SignupRequest do
  @moduledoc false
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "SignupRequest",
    type: :object,
    additionalProperties: false,
    properties: %{
      username: %Schema{type: :string, minLength: 1},
      password: %Schema{type: :string, minLength: 1},
      passwordConfirmation: %Schema{type: :string, minLength: 1}
    },
    required: [:username, :password, :passwordConfirmation]
  })
end

defmodule MusicBoxWeb.Schemas.SignupResponse do
  @moduledoc false
  alias MusicBoxWeb.Schemas.ChangesetError
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "SignupResponse",
    description: "A successful Signup attempt returns currentUser and sessionToken",
    type: :object,
    additionalProperties: false,
    properties: %{
      ok: %Schema{type: :boolean, example: "true"},
      sessionToken: MusicBoxWeb.Schemas.SessionToken,
      currentUser: MusicBoxWeb.Schemas.User
    },
    required: [:ok, :sessionToken, :currentUser]
  })
end

defmodule MusicBoxWeb.Schemas.SignupError do
  @moduledoc false
  alias MusicBoxWeb.Schemas.ChangesetError
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "SignupError",
    description: "A response containing validation errors keyed by field name",
    type: :object,
    additionalProperties: false,
    properties: %{
      ok: %Schema{type: :boolean, example: "false"},
      fields: %Schema{
        type: :object,
        description: "Map of field names to their validation errors",
        additionalProperties: ChangesetError,
        example: %{
          "name" => %{"message" => "can't be blank"}
        }
      }
    },
    required: [:fields]
  })
end
