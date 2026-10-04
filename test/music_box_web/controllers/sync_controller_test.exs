defmodule MusicBoxWeb.SyncControllerTest do
  use MusicBoxWeb.ConnCase, async: true

  setup :register_and_log_in_user

  test "syncs flat entities that match the schema", %{conn: conn} do
    assert %{"tracks" => [track | _], "albums" => [_ | _], "artists" => [_ | _]} =
             conn |> get(~p"/api/sync") |> api_response(200, "SyncResponse")

    # Albums and artists are synced separately, not embedded in every track.
    refute Map.has_key?(track, "album")
    refute Map.has_key?(track, "artist")
  end
end
