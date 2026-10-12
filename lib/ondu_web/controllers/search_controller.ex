defmodule OnduWeb.SearchController do
  use OnduWeb, :controller

  alias Ondu.Search

  operation :search,
    summary: "Search for artists, albums or tracks",
    tags: ["Search"],
    parameters: [
      query: [
        in: :query,
        description: "A search term to use across artists, albums and tracks.",
        type: :string,
        required: true
      ]
    ],
    responses: [
      ok:
        {"Returns a list of search results (artists, albums, tracks).", "application/json",
         Schemas.SearchResults},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error}
    ]

  def search(conn, %{"query" => query}) do
    result = Search.search(query)
    render(conn, :result, result: result)
  end
end
