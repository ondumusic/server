defmodule MusicBoxWeb.SettingsControllerTest do
  use MusicBoxWeb.ConnCase, async: false

  alias MusicBox.Settings

  @music_path Path.expand("../../support/fixtures/music_files", __DIR__)

  setup do
    Settings.set(%{
      music_path: @music_path,
      poll_interval: 60,
      scan_type: :quick,
      strip_sort_prefixes: ["the"]
    })

    []
  end

  describe "settings" do
    setup :register_and_log_in_user

    test "returns current settings", %{conn: conn} do
      assert %{
               "musicPath" => @music_path,
               "pollInterval" => 60,
               "scanType" => "quick",
               "stripSortPrefixes" => ["the"]
             } =
               conn
               |> get(~p"/api/settings")
               |> api_response(200, "Settings")
    end

    test "can change settings", %{conn: conn} do
      assert %{
               "ok" => true,
               "settings" => %{
                 "scanType" => "full",
                 "stripSortPrefixes" => []
               }
             } =
               conn
               |> patch(~p"/api/settings", %{
                 scanType: "full",
                 stripSortPrefixes: []
               })
               |> api_response(200, "UpdateSettingsResponse")
    end

    test "validates new musicPath setting", %{conn: conn} do
      assert %{
               "ok" => false,
               "fields" => %{
                 "musicPath" => %{"message" => "is not a directory"}
               }
             } =
               conn
               |> patch(~p"/api/settings", %{
                 musicPath: "/music"
               })
               |> api_response(422, "UpdateSettingsError")
    end

    test "validates new pollInterval setting (requires minimum 5 minutes)", %{conn: conn} do
      assert %{
               "ok" => false,
               "fields" => %{
                 "pollInterval" => %{"message" => "must be greater than or equal to 5"}
               }
             } =
               conn
               |> patch(~p"/api/settings", %{
                 pollInterval: 1
               })
               |> api_response(422, "UpdateSettingsError")
    end
  end

  describe "forbidden when not authenticated" do
    test "forbidden GET on /api/settings", %{conn: conn} do
      assert_raise MusicBoxWeb.UnauthorizedError, fn ->
        get(conn, "/api/settings")
      end
    end

    test "forbidden PATCH on /api/settings", %{conn: conn} do
      assert_raise MusicBoxWeb.UnauthorizedError, fn ->
        patch(conn, "/api/settings", %{
          pollInterval: 10
        })
      end
    end
  end
end
