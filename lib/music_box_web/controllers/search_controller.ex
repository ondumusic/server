defmodule MusicBoxWeb.SearchController do
  use MusicBoxWeb, :controller

  alias MusicBox.Search

  def search(conn, %{"query" => query}) do
    results = Search.search(query)
    render(conn, :results, results: results)
  end
end
