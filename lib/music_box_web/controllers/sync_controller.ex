defmodule MusicBoxWeb.SyncController do
  use MusicBoxWeb, :controller

  alias MusicBox.Sync

  operation :sync,
    summary: "Sync the entire library (metadata).",
    description: """
    This generally helps provide the best experience for end-users by syncing
    the metadata to be available offline and use local database techniques when
    displaying, sorting, searching, etc. in the library.

    The initial sync can take a couple of requests before it is completed,
    depending on the size of your library. But if you store the last returned
    `cursor` from then on sync requests should only return new changes.

    If you want to also sync the actual tracks this is something you would have
    to manage in your application by building a download queue and keeping track
    of the download status etc.
    """,
    tags: ["Sync"],
    parameters: [
      cursor: [
        in: :query,
        description: "Cursor from previous sync response to get only changes since then.",
        type: :string,
        required: false
      ]
    ],
    responses: [
      ok:
        {"Returns a cursor-paginated list of entities from the library.", "application/json",
         Schemas.SyncResponse},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error}
    ]

  def sync(conn, params) do
    result = Sync.get_entities(params)
    new_cursor = Sync.encode_cursor(result, params)

    render(conn, :result, result: result, cursor: new_cursor)
  end
end
