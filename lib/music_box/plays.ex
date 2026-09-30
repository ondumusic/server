defmodule MusicBox.Plays do
  @moduledoc """
  Play history is reported by clients once a track has been played long enough,
  the play count and last played date of tracks are kept up to date with them.
  """

  import Ecto.Changeset
  import Ecto.Query

  alias MusicBox.Plays.Play
  alias MusicBox.Repo
  alias MusicBox.Tracks.Track

  @max_batch_size 500
  @types %{id: Ecto.UUID, track_id: Ecto.UUID, played_at: :utc_datetime}

  @doc """
  Stores a batch of plays. Since play ids are supposed to be idempotent there
  should not be any duplicates recorded. It will also discard plays for tracks
  that don't (or no longer) exist.
  """
  @spec record([map()]) :: :ok | {:error, :invalid_plays | :too_many_plays}
  def record(plays) when is_list(plays) and length(plays) > @max_batch_size,
    do: {:error, :too_many_plays}

  def record([]), do: :ok

  def record(plays) when is_list(plays) do
    with {:ok, plays} <- cast_plays(plays),
         {:ok, _count} <- Repo.transact(fn -> store(plays) end),
         do: :ok
  end

  def record(_plays), do: {:error, :invalid_plays}

  defp cast_plays(plays) do
    changesets =
      Enum.map(plays, fn play ->
        {%{}, @types}
        |> cast(if(is_map(play), do: play, else: %{}), Map.keys(@types))
        |> validate_required(Map.keys(@types))
      end)

    if Enum.all?(changesets, & &1.valid?) do
      {:ok, Enum.map(changesets, &apply_changes/1)}
    else
      {:error, :invalid_plays}
    end
  end

  defp store(plays) do
    track_ids = existing_track_ids(plays)
    now = DateTime.utc_now(:second)

    entries =
      for play <- plays, play.track_id in track_ids do
        Map.put(play, :inserted_at, now)
      end

    {count, _} = Repo.insert_all(Play, entries, on_conflict: :nothing, conflict_target: :id)
    touch_tracks(track_ids, now)
    {:ok, count}
  end

  defp existing_track_ids(plays) do
    track_ids = plays |> Enum.map(& &1.track_id) |> Enum.uniq()

    from(t in Track, where: t.id in ^track_ids, select: t.id)
    |> Repo.all()
  end

  # Also touch tracks.updated_at so clients will receive the changes on next sync
  defp touch_tracks(track_ids, now) do
    stats =
      from(p in Play,
        where: p.track_id in ^track_ids,
        group_by: p.track_id,
        select: %{track_id: p.track_id, count: count(p.id), last_played_at: max(p.played_at)}
      )

    from(t in Track,
      join: s in subquery(stats),
      on: t.id == s.track_id,
      where: t.play_count != s.count,
      update: [set: [play_count: s.count, last_played_at: s.last_played_at, updated_at: ^now]]
    )
    |> Repo.update_all([])
  end
end
