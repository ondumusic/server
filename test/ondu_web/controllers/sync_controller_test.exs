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

  test "continues from cursors issued before timestamps had microseconds", %{conn: conn} do
    whole_second = %{DateTime.utc_now() | microsecond: {0, 6}}

    for schema <- [Ondu.Artists.Artist, Ondu.Albums.Album, Ondu.Tracks.Track] do
      Repo.update_all(schema, set: [updated_at: whole_second])
    end

    %{"cursor" => cursor} = conn |> get(~p"/api/sync") |> json_response(200)
    {:ok, decoded} = Ondu.Sync.decode_cursor(cursor)

    truncated =
      Map.new(decoded, fn
        {key, [date, id]} ->
          {:ok, date, _offset} = DateTime.from_iso8601(date)
          {key, [DateTime.truncate(date, :second), id]}

        entry ->
          entry
      end)

    assert %{"tracks" => [], "albums" => [], "artists" => []} =
             conn
             |> get(~p"/api/sync?cursor=v1-#{encode(truncated)}")
             |> api_response(200, "SyncResponse")
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
      log_deletion()

      assert %{"tracks" => [], "deletions" => [_]} =
               conn |> get(~p"/api/sync?cursor=#{cursor}") |> api_response(200, "SyncResponse")
    end

    test "refuses a cursor with an invalid schema", %{conn: conn, cursor: cursor} do
      cursor = with_schema(cursor, %{"server" => "one", "client" => 1})

      assert %{"error" => "Invalid cursor"} =
               conn |> get(~p"/api/sync?cursor=#{cursor}") |> api_response(400, "Error")
    end
  end

  test "syncs changes made in the same second as the previous sync", %{conn: conn} do
    log_deletion()
    %{"cursor" => cursor, "deletions" => [_]} = conn |> get(~p"/api/sync") |> json_response(200)

    # This is an id that sorts before the one in the cursor
    log_deletion(entity_id: "00000000-0000-4000-8000-000000000000")

    assert %{"deletions" => [_]} =
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

  defp with_schema(cursor, schema) do
    {:ok, decoded} = Ondu.Sync.decode_cursor(cursor)

    decoded =
      if schema, do: Map.put(decoded, "schema", schema), else: Map.delete(decoded, "schema")

    "v1-" <> encode(decoded)
  end

  defp log_deletion(attrs \\ []) do
    deletion = %Ondu.DeletionLog{
      entity_type: :track,
      entity_id: Ecto.UUID.generate(),
      deleted_at: DateTime.utc_now()
    }

    Ondu.Repo.insert!(struct!(deletion, attrs))
  end
end
