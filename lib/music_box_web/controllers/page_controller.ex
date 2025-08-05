defmodule MusicBoxWeb.PageController do
  use MusicBoxWeb, :controller

  def react(conn, _params) do
    render(conn, :react)
  end
end
