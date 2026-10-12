defmodule OnduWeb.NoticeController do
  use OnduWeb, :controller

  alias Ondu.Notices

  operation :dismiss,
    summary: "Dismiss a notice",
    description: "Dismisses the notice for all clients, returns a list of remaining notices.",
    tags: ["Notices"],
    parameters: [
      notice_id: [in: :path, type: %OpenApiSpex.Schema{type: :string, format: :uuid}]
    ],
    responses: [
      ok: {"The remaining notices.", "application/json", Schemas.Notices},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error},
      not_found: {"Notice not found (or no longer active).", "application/json", Schemas.Error}
    ]

  def dismiss(conn, %{"notice_id" => notice_id}) do
    case Notices.dismiss(notice_id) do
      {:ok, _notice} ->
        render(conn, :notices, notices: Notices.active())

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Not Found"})
    end
  end
end
