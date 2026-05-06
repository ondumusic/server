defmodule MusicBoxWeb.Schemas.FractionalIndex do
  @moduledoc false
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "FractionalIndex",
    type: :string,
    example: "a0",
    minLength: 2,
    maxLength: MusicBox.FractionalIndex.max_length(),
    pattern: ~r/^[A-Za-z][0-9A-Za-z]*$/,
    description: """
    The position of the item in the playlist using fractional indexing
    using the default base-62 alphabet (`0-9A-Za-z`).
    """
  })
end
