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

  describe "schema version" do
    setup %{conn: conn} do
      %{"cursor" => cursor} = conn |> get(~p"/api/sync?schemaVersion=1") |> json_response(200)
      log_deletion()

      %{"cursor" => cursor, "deletions" => [_deletion]} =
        conn |> get(~p"/api/sync?cursor=#{cursor}&schemaVersion=1") |> json_response(200)

      [cursor: cursor]
    end

    test "continues when schema version did not change", %{conn: conn, cursor: cursor} do
      assert %{"tracks" => [], "deletions" => []} =
               conn
               |> get(~p"/api/sync?cursor=#{cursor}&schemaVersion=1")
               |> api_response(200, "SyncResponse")
    end

    test "restarts when the server schema version changed", %{conn: conn, cursor: cursor} do
      cursor = with_schema(cursor, %{"server" => 0, "client" => 1})

      assert %{"tracks" => [_ | _], "albums" => [_ | _], "deletions" => []} =
               conn
               |> get(~p"/api/sync?cursor=#{cursor}&schemaVersion=1")
               |> api_response(200, "SyncResponse")
    end

    test "restarts when the client schema version changed", %{conn: conn, cursor: cursor} do
      assert %{"tracks" => [_ | _], "albums" => [_ | _], "deletions" => [], "cursor" => next} =
               conn
               |> get(~p"/api/sync?cursor=#{cursor}&schemaVersion=2")
               |> api_response(200, "SyncResponse")

      # The new cursor remembers the client version, so this was a one-off.
      assert %{"tracks" => [], "deletions" => []} =
               conn |> get(~p"/api/sync?cursor=#{next}&schemaVersion=2") |> json_response(200)
    end

    test "support for old cursors from before schema versions", %{conn: conn, cursor: cursor} do
      cursor = with_schema(cursor, nil)

      assert %{"tracks" => [_ | _], "deletions" => []} =
               conn
               |> get(~p"/api/sync?cursor=#{cursor}&schemaVersion=1")
               |> api_response(200, "SyncResponse")
    end

    test "continues for old client that send no schema version", %{conn: conn} do
      %{"cursor" => cursor} = conn |> get(~p"/api/sync") |> json_response(200)
      log_deletion(1)

      assert %{"tracks" => [], "deletions" => [_]} =
               conn |> get(~p"/api/sync?cursor=#{cursor}") |> api_response(200, "SyncResponse")
    end

    test "refuses a cursor with an invalid schema", %{conn: conn, cursor: cursor} do
      cursor = with_schema(cursor, %{"server" => "one", "client" => 1})

      assert %{"error" => "Invalid cursor"} =
               conn |> get(~p"/api/sync?cursor=#{cursor}") |> api_response(400, "Error")
    end
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

  defp with_schema(cursor, schema) do
    {:ok, decoded} = Ondu.Sync.decode_cursor(cursor)

    decoded =
      if schema, do: Map.put(decoded, "schema", schema), else: Map.delete(decoded, "schema")

    "v1-" <> encode(decoded)
  end

  defp log_deletion(seconds_from_now \\ 0) do
    Ondu.Repo.insert!(%Ondu.DeletionLog{
      entity_type: :track,
      entity_id: Ecto.UUID.generate(),
      deleted_at: DateTime.add(DateTime.utc_now(:second), seconds_from_now, :second)
    })
  end
end
