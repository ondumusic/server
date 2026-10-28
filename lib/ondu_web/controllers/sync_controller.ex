defmodule OnduWeb.SyncController do
  use OnduWeb, :controller

  alias Ondu.Notices
  alias Ondu.Sync

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
      bad_request: {"Invalid cursor.", "application/json", Schemas.Error},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error}
    ]

  def sync(conn, params) do
    case Sync.decode_cursor(params["cursor"]) do
      {:ok, cursor} ->
        result = Sync.get_entities(cursor, Sync.parse_limit(params["limit"]))
        new_cursor = Sync.encode_cursor(result, cursor)
        notices = Notices.active()

        render(conn, :result, result: result, cursor: new_cursor, notices: notices)

      {:error, :invalid_cursor} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid cursor"})
    end
  end
end
