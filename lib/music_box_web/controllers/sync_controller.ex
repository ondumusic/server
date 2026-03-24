defmodule MusicBoxWeb.SyncController do
  use MusicBoxWeb, :controller

  alias MusicBox.Sync

  def sync(conn, params) do
    result = Sync.get_entities(params)
    new_cursor = Sync.encode_cursor(result, params)

    render(conn, :result, result: result, cursor: new_cursor)
  end
end
