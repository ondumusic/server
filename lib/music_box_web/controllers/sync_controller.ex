defmodule MusicBoxWeb.SyncController do
  use MusicBoxWeb, :controller

  alias MusicBox.Sync

  operation :sync,
    summary: "Sync the entire library (metadata).",
    tags: ["Sync"],
    parameters: [
      cursor: [in: :path, type: :string, required: false]
    ],
    responses: [
      ok: {"Sync", "application/json", Schemas.SyncResponse},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]

  def sync(conn, params) do
    result = Sync.get_entities(params)
    new_cursor = Sync.encode_cursor(result, params)

    render(conn, :result, result: result, cursor: new_cursor)
  end
end
