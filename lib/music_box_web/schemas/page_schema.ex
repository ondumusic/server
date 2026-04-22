defmodule MusicBoxWeb.Schemas.Page do
  @moduledoc false
  alias OpenApiSpex.Schema

  def of(item_schema, opts \\ []) do
    title = Keyword.fetch!(opts, :title)
    subtype = Keyword.fetch!(opts, :__subtype)

    %Schema{
      title: title,
      type: :object,
      properties: %{
        __type: %Schema{
          type: :string,
          enum: ["page"],
          default: "page",
          description: "Entity type"
        },
        __subtype: %Schema{
          type: :string,
          enum: [subtype],
          default: subtype,
          description: "Paginated entity type"
        },
        entries: %Schema{
          type: :array,
          items: item_schema
        },
        pageNumber: %Schema{type: :integer, minimum: 1, example: 1},
        pageSize: %Schema{type: :integer, minimum: 1, example: 25},
        totalEntries: %Schema{type: :integer, minimum: 0, example: 142},
        totalPages: %Schema{type: :integer, minimum: 0, example: 6}
      },
      required: [
        :__type,
        :__subtype,
        :entries,
        :pageNumber,
        :pageSize,
        :totalEntries,
        :totalPages
      ]
    }
  end
end
