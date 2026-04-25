defmodule MusicBoxWeb.Schemas.LoginRequest do
  @moduledoc false
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "LoginRequest",
    type: :object,
    additionalProperties: false,
    properties: %{
      username: %Schema{type: :string, minLength: 1},
      password: %Schema{type: :string, minLength: 1}
    },
    required: [:username, :password]
  })
end

defmodule MusicBoxWeb.Schemas.LoginResponse do
  @moduledoc false
  alias MusicBoxWeb.Schemas.ChangesetError
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "LoginResponse",
    description: "A successful login attempt returns currentUser and sessionToken",
    type: :object,
    additionalProperties: false,
    properties: %{
      ok: %Schema{type: :boolean, example: true},
      sessionToken: MusicBoxWeb.Schemas.SessionToken,
      currentUser: MusicBoxWeb.Schemas.User
    },
    required: [:ok, :sessionToken, :currentUser]
  })
end

defmodule MusicBoxWeb.Schemas.LoginError do
  @moduledoc false
  alias MusicBoxWeb.Schemas.ChangesetError
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "LoginError",
    description: "A response containing validation errors keyed by field name",
    type: :object,
    additionalProperties: false,
    properties: %{
      ok: %Schema{type: :boolean, example: false},
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
