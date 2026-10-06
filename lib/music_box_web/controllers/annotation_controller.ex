defmodule MusicBoxWeb.AnnotationController do
  use MusicBoxWeb, :controller

  alias MusicBox.Annotations
  alias MusicBox.Annotations.Annotation

  @path_params [
    namespace: [
      in: :path,
      required: true,
      description: """
      A namespace can be used to group annotations, for example if you write a
      script that needs to persist data it could be the name of your script.

      1 to 64 characters of `a-z`, `0-9`, `.`, `_` and `-`.
      """,
      schema: %OpenApiSpex.Schema{type: :string, pattern: "^[a-z0-9._-]{1,64}$"}
    ],
    entity_type: [
      in: :path,
      required: true,
      schema: %OpenApiSpex.Schema{
        type: :string,
        enum: Enum.map(Annotation.entity_types(), &to_string/1)
      }
    ]
  ]

  operation :index,
    summary: "List annotations",
    description: """
    Annotations are data stored by scripts using the API. The server itself does
    nothing with them and they are not part of sync.

    Lists all annotations inside the a namespace for an entity type.
    """,
    tags: ["Annotations"],
    parameters:
      @path_params ++
        Schemas.Page.params() ++
        [
          page_size: [
            in: :query,
            description: "Defaults to 500.",
            schema: %OpenApiSpex.Schema{type: :integer, minimum: 1, maximum: 1000}
          ]
        ],
    responses: [
      ok: {"A page of annotations.", "application/json", Schemas.AnnotationPage},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error},
      unprocessable_entity:
        {"Invalid namespace or entity type.", "application/json", Schemas.Error}
    ]

  def index(conn, %{"namespace" => namespace, "entity_type" => entity_type} = params) do
    case Annotations.paginate_annotations(namespace, entity_type, params) do
      {:ok, page} -> render(conn, :annotations, page: page)
      {:error, reason} -> render_error(conn, reason)
    end
  end

  operation :update,
    summary: "Write annotations",
    description: """
    Writes up to 500 annotations to a namespace for an entity type. The data
    replaces the current data of an entity, `null` removes it. Entries for
    entities that don't exist are skipped and returned.
    """,
    tags: ["Annotations"],
    parameters: @path_params,
    request_body: {"Annotations", "application/json", Schemas.PutAnnotationsRequest},
    responses: [
      ok: {"The annotations were written.", "application/json", Schemas.PutAnnotationsResponse},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error},
      unprocessable_entity: {"Invalid annotations.", "application/json", Schemas.Error}
    ]

  def update(conn, %{"namespace" => namespace, "entity_type" => entity_type} = params) do
    case Annotations.put_annotations(namespace, entity_type, Map.get(params, "entries")) do
      {:ok, result} -> render(conn, :result, result)
      {:error, reason} -> render_error(conn, reason)
    end
  end

  defp render_error(conn, reason) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: to_string(reason)})
  end
end
