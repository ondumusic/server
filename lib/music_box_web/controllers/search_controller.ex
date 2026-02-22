defmodule MusicBoxWeb.SearchController do
  use MusicBoxWeb, :controller

  alias MusicBox.Search

  def search(conn, %{"query" => query}) do
    result = Search.search(query)
    render(conn, :result, result: result)
  end
end
