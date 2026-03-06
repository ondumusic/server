defmodule MusicBoxWeb.SyncController do
  use MusicBoxWeb, :controller

  alias MusicBox.Sync

  def sync(conn, params) do
    result = Sync.get_entities(params)
    cursor = Sync.encode_cursor(result)

    render(conn, :result, result: result, cursor: cursor)
  end
end
