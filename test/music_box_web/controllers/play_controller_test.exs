defmodule MusicBoxWeb.PlayControllerTest do
  use MusicBoxWeb.ConnCase, async: true

  alias MusicBox.Tracks.Track

  setup :register_and_log_in_user

  test "records plays", %{conn: conn} do
    track = Track |> Ecto.Query.first() |> Repo.one!()
    play = %{id: Ecto.UUID.generate(), trackId: track.id, playedAt: "2026-09-01T10:00:00Z"}

    assert %{"ok" => true} =
             conn
             |> post(~p"/api/plays", %{plays: [play]})
             |> api_response(200, "RecordPlaysResponse")

    assert %{play_count: 1} = Repo.reload!(track)
  end

  test "refuses invalid plays", %{conn: conn} do
    assert %{"error" => "invalid_plays"} =
             conn
             |> post(~p"/api/plays", %{plays: [%{id: "invalid"}]})
             |> api_response(422, "Error")
  end
end
