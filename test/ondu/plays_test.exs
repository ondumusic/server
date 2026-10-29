defmodule Ondu.PlaysTest do
  use Ondu.DataCase, async: true

  alias Ondu.Plays
  alias Ondu.Plays.Play
  alias Ondu.Tracks.Track

  setup do
    [track, other_track] = Repo.all(from(t in Track, order_by: t.id, limit: 2))
    [track: track, other_track: other_track]
  end

  defp play(track, played_at) do
    %{"id" => Ecto.UUID.generate(), "track_id" => track.id, "played_at" => played_at}
  end

  test "stores plays and updates the play count and last played date of tracks", %{
    track: track,
    other_track: other_track
  } do
    track = update_record(track, %{updated_at: ~U[2026-01-01 00:00:00.000000Z]})

    assert :ok =
             Plays.record([
               play(track, "2026-09-01T10:00:00Z"),
               play(track, "2026-09-02T10:00:00.123+02:00"),
               play(other_track, "2026-09-01T12:00:00Z")
             ])

    assert %{play_count: 2, last_played_at: ~U[2026-09-02 08:00:00Z], updated_at: updated_at} =
             Repo.reload!(track)

    assert DateTime.after?(updated_at, ~U[2026-01-01 00:00:00.000000Z])
    assert %{play_count: 1} = Repo.reload!(other_track)
  end

  test "ignores plays that were stored before", %{track: track} do
    plays = [play(track, "2026-09-01T10:00:00Z")]
    :ok = Plays.record(plays)
    track = update_record(Repo.reload!(track), %{updated_at: ~U[2026-01-01 00:00:00.000000Z]})

    assert :ok = Plays.record(plays ++ plays)
    assert %{play_count: 1, updated_at: ~U[2026-01-01 00:00:00.000000Z]} = Repo.reload!(track)
  end

  test "ignores plays of tracks that no longer exist", %{track: track} do
    missing = %{id: Ecto.UUID.generate()}

    assert :ok =
             Plays.record([
               play(missing, "2026-09-01T10:00:00Z"),
               play(track, "2026-09-01T10:00:00Z")
             ])

    assert Repo.aggregate(Play, :count) == 1
  end

  test "refuses invalid plays", %{track: track} do
    valid = play(track, "2026-09-01T10:00:00Z")

    for invalid <- [%{valid | "id" => "not-a-uuid"}, Map.delete(valid, "played_at"), "play"] do
      assert {:error, :invalid_plays} = Plays.record([valid, invalid])
    end

    assert {:error, :invalid_plays} = Plays.record(nil)
    assert {:error, :too_many_plays} = Plays.record(List.duplicate(valid, 501))
    assert Repo.aggregate(Play, :count) == 0
  end

  test "deletes the plays of deleted tracks", %{track: track} do
    :ok = Plays.record([play(track, "2026-09-01T10:00:00Z")])
    Repo.delete!(track)

    assert Repo.aggregate(Play, :count) == 0
  end
end
