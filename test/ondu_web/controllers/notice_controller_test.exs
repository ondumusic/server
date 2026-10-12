defmodule OnduWeb.NoticeControllerTest do
  use OnduWeb.ConnCase, async: true

  alias Ondu.Notices

  setup :register_and_log_in_user

  test "sync includes all active notices", %{conn: conn} do
    {:ok, notice} = Notices.raise_notice(:library_unavailable)
    id = notice.id

    assert %{"notices" => [%{"id" => ^id, "code" => "library_unavailable", "level" => "warning"}]} =
             conn |> get(~p"/api/sync") |> api_response(200, "SyncResponse")

    # Also with a cursor, notices are not part of the cursor.
    %{"cursor" => cursor} = conn |> get(~p"/api/sync") |> json_response(200)

    assert %{"notices" => [%{"id" => ^id}]} =
             conn |> get(~p"/api/sync?cursor=#{cursor}") |> json_response(200)
  end

  test "dismisses a notice", %{conn: conn} do
    {:ok, notice} = Notices.raise_notice(:library_unavailable)

    assert %{"notices" => []} =
             conn
             |> post(~p"/api/notices/#{notice.id}/dismiss")
             |> api_response(200, "Notices")

    assert %{"notices" => []} = conn |> get(~p"/api/sync") |> json_response(200)
  end

  test "returns not found for unknown notices", %{conn: conn} do
    assert conn |> post(~p"/api/notices/#{Ecto.UUID.generate()}/dismiss") |> json_response(404)
  end
end
