defmodule OnduWeb.IssueController do
  use OnduWeb, :controller

  alias Ondu.Issues

  operation :issues,
    summary: "List albums and tracks with potential metadata issues",
    description: """
    Albums and tracks with missing or bad metadata, e.g. missing tags or
    non-square artwork. Tracks that are not linked to an artist or album are
    listed first, followed by albums ordered by artist.
    """,
    tags: ["Issues"],
    parameters:
      Schemas.Page.params() ++
        [
          code: [
            in: :query,
            description: "Only include entries with this specific issue.",
            schema: %OpenApiSpex.Schema{
              type: :string,
              enum: Enum.map(Issues.codes(), &to_string/1)
            }
          ]
        ],
    responses: [
      ok: {"A paginated list of issues.", "application/json", Schemas.IssuePage},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error}
    ]

  def issues(conn, params) do
    render(conn, :issues, page: Issues.list(params))
  end
end
