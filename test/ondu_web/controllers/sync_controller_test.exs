defmodule OnduWeb.SyncControllerTest do
  use OnduWeb.ConnCase, async: true

  setup :register_and_log_in_user

  test "syncs flat entities that match the schema", %{conn: conn} do
    assert %{"tracks" => [track | _], "albums" => [_ | _], "artists" => [_ | _]} =
             conn |> get(~p"/api/sync") |> api_response(200, "SyncResponse")

    # Albums and artists are synced separately, not embedded in every track.
    refute Map.has_key?(track, "album")
    refute Map.has_key?(track, "artist")
  end

  test "continues from the cursor of the previous response", %{conn: conn} do
    assert %{"cursor" => cursor, "complete" => true} =
             conn |> get(~p"/api/sync") |> api_response(200, "SyncResponse")

    assert %{"tracks" => [], "albums" => [], "artists" => [], "cursor" => ^cursor} =
             conn |> get(~p"/api/sync?cursor=#{cursor}") |> api_response(200, "SyncResponse")
  end

  test "refuses invalid cursors", %{conn: conn} do
    position = ["2026-01-01T00:00:00Z", Ecto.UUID.generate()]

    for cursor <- [
          "garbage",
          "v9-" <> encode(%{"tracks" => position}),
          "v1-not base64!",
          "v1-" <> Base.url_encode64("not json"),
          "v1-" <> Base.url_encode64("[]"),
          "v1-" <> encode(%{"tracks" => "position"}),
          "v1-" <> encode(%{"tracks" => ["yesterday", Ecto.UUID.generate()]}),
          "v1-" <> encode(%{"tracks" => ["2026-01-01T00:00:00Z", "not an id"]})
        ] do
      assert %{"error" => "Invalid cursor"} =
               conn |> get(~p"/api/sync?cursor=#{cursor}") |> api_response(400, "Error")
    end
  end

  defp encode(cursor), do: cursor |> JSON.encode!() |> Base.url_encode64()
end
