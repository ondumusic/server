defmodule MusicBoxWeb.SearchController do
  use MusicBoxWeb, :controller

  alias MusicBox.Search

  operation :search,
    summary: "Search for artists, albums or tracks",
    tags: ["Search"],
    parameters: [
      query: [in: :query, type: :string, required: true]
    ],
    responses: [
      ok: {"SearchResults", "application/json", Schemas.SearchResults},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]

  def search(conn, %{"query" => query}) do
    result = Search.search(query)
    render(conn, :result, result: result)
  end
end
