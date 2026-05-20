defmodule MusicBoxWeb.Schemas.UpdatePasswordRequest do
  @moduledoc false
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "UpdatePasswordRequest",
    type: :object,
    additionalProperties: false,
    properties: %{
      password: %Schema{type: :string, minLength: 1},
      passwordConfirmation: %Schema{type: :string, minLength: 1},
      currentPassword: %Schema{type: :string, minLength: 1}
    },
    required: [:password, :psaswordConfirmation, :updatePassword]
  })
end

defmodule MusicBoxWeb.Schemas.UpdatePasswordResponse do
  @moduledoc false
  alias MusicBoxWeb.Schemas.ChangesetError
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "UpdatePasswordResponse",
    description: "A successful password change just returns ok.",
    type: :object,
    additionalProperties: false,
    properties: %{
      ok: %Schema{type: :boolean, example: true},
      sessionToken: MusicBoxWeb.Schemas.SessionToken
    },
    required: [:ok, :sessionToken]
  })
end

defmodule MusicBoxWeb.Schemas.UpdatePasswordError do
  @moduledoc false
  alias MusicBoxWeb.Schemas.ChangesetError
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "UpdatePasswordError",
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
          "password" => %{"message" => "can't be blank"}
        }
      }
    },
    required: [:fields]
  })
end
