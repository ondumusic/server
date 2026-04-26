defmodule MusicBox.Playlists.Operations do
  @moduledoc false

  alias MusicBox.Playlists.{Playlist, PlaylistItem}
  alias MusicBox.Repo
  alias MusicBox.Tracks.Track

  import Ecto.Query

  @max_batch_operations 250

  @type position :: String.t()
  @type add_op :: %{track_id: String.t(), position: position()}
  @type move_op :: %{item_id: String.t(), position: position()}
  @type remove_op :: String.t()

  @type t :: %{
          optional(String.t()) => [add_op()] | [move_op()] | [remove_op()]
        }

  @type result :: %{
          added: [PlaylistItem.t()],
          moved: [PlaylistItem.t()],
          removed: [String.t()]
        }

  @type error ::
          {:error, {:too_many_operations, %{count: non_neg_integer(), limit: non_neg_integer()}}}
          | {:error, {:missing_items, [String.t()]}}
          | {:error, {:missing_tracks, [String.t()]}}
          | {:error, {:conflict_items, [String.t()]}}
          | {:error, {:conflict_positions, [position()]}}
          | {:error, :playlist_is_folder}

  @spec batch_update(Playlist.t(), t()) :: {:ok, result()} | error()
  def batch_update(%{is_folder: true}, _changes), do: {:error, :playlist_is_folder}

  def batch_update(playlist, changes) do
    case validate(playlist, changes) do
      {:ok, validated} -> execute(playlist, validated)
      error -> error
    end
  end

  defp validate(playlist, changes) do
    adds = Map.get(changes, "add", [])
    moves = Map.get(changes, "move", [])
    removes = Map.get(changes, "remove", [])

    move_ids = Enum.map(moves, &Map.get(&1, "item_id"))
    remove_ids = removes
    combined_ids = Enum.uniq(move_ids ++ remove_ids)

    with :ok <- validate_batch_size(adds, moves, removes),
         :ok <- validate_item_id_conflicts(moves, removes),
         :ok <- validate_unique_items(:move, Enum.map(moves, & &1["item_id"])),
         :ok <- validate_unique_items(:remove, removes),
         :ok <- validate_positions(adds, moves),
         :ok <- validate_tracks(adds),
         existing_items <- get_existing_items(playlist, combined_ids),
         :ok <- validate_items(existing_items, combined_ids),
         :ok <- validate_unique_positions(playlist, adds, moves) do
      {:ok,
       %{
         adds: adds,
         moves: moves,
         removes: removes,
         existing_items: existing_items
       }}
    end
  end

  defp validate_batch_size(adds, moves, removes) do
    count = length(adds) + length(moves) + length(removes)

    if count <= @max_batch_operations do
      :ok
    else
      {:error, {:too_many_operations, %{count: count, limit: @max_batch_operations}}}
    end
  end

  defp validate_item_id_conflicts(moves, removes) do
    conflict_items =
      Enum.flat_map(moves, fn %{"item_id" => item_id} ->
        if Enum.member?(removes, item_id) do
          [item_id]
        else
          []
        end
      end)

    if conflict_items == [] do
      :ok
    else
      {:error, {:conflict_items, conflict_items}}
    end
  end

  defp validate_unique_items(_op, items) do
    duplicates = find_duplicates(items)

    if duplicates == [] do
      :ok
    else
      {:error, {:conflict_items, duplicates}}
    end
  end

  defp validate_positions(adds, moves) do
    conflict_positions = find_duplicates_by(adds, moves, "position")

    if conflict_positions == [] do
      :ok
    else
      {:error, {:conflict_items, conflict_positions}}
    end
  end

  defp validate_unique_positions(playlist, adds, moves) do
    combined_positions =
      List.flatten([
        adds,
        moves
      ])
      |> Enum.map(& &1["position"])

    from(i in PlaylistItem,
      where: i.playlist_id == ^playlist.id and i.position in ^combined_positions,
      select: i.position
    )
    |> Repo.all()
    |> case do
      [] ->
        :ok

      conflict_positions ->
        {:error, {:conflict_positions, conflict_positions}}
    end
  end

  defp validate_tracks(adds) do
    track_ids = Enum.map(adds, &Map.get(&1, "track_id"))

    existing_tracks =
      from(t in Track,
        where: t.id in ^track_ids
      )
      |> Repo.all()
      |> Map.new(&{&1.id, &1})

    missing_tracks =
      Enum.flat_map(track_ids, fn
        track_id when is_map_key(existing_tracks, track_id) -> []
        track_id -> [track_id]
      end)

    if missing_tracks == [] do
      :ok
    else
      {:error, {:missing_tracks, missing_tracks}}
    end
  end

  defp validate_items(existing_items, combined_ids) do
    missing_items =
      Enum.flat_map(combined_ids, fn
        playlist_item_id when is_map_key(existing_items, playlist_item_id) -> []
        playlist_item_id -> [playlist_item_id]
      end)

    if missing_items == [] do
      :ok
    else
      {:error, {:missing_items, missing_items}}
    end
  end

  defp get_existing_items(playlist, combined_ids) do
    from(i in PlaylistItem,
      where: i.playlist_id == ^playlist.id and i.id in ^combined_ids
    )
    |> Repo.all()
    |> Map.new(&{&1.id, &1})
  end

  defp execute(playlist, %{
         adds: adds,
         moves: moves,
         removes: removes,
         existing_items: existing_items
       }) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    removed =
      if removes != [] do
        {_count, results} =
          from(i in PlaylistItem,
            where: i.playlist_id == ^playlist.id and i.id in ^removes,
            select: i.id
          )
          |> Repo.delete_all(returning: true)

        results
      end

    moved =
      if moves != [] do
        rows =
          Enum.map(moves, fn %{"item_id" => id, "position" => pos} ->
            existing_items
            |> Map.fetch!(id)
            |> Map.from_struct()
            |> Map.take([
              :id,
              :playlist_id,
              :track_id,
              :position,
              :inserted_at,
              :updated_at
            ])
            |> Map.merge(%{position: pos, updated_at: now})
          end)

        {_count, results} =
          Repo.insert_all(
            PlaylistItem,
            rows,
            on_conflict: {:replace, [:position, :updated_at]},
            conflict_target: [:id],
            returning: true
          )

        results
      end

    added =
      if adds != [] do
        rows =
          Enum.map(adds, fn %{"track_id" => id, "position" => pos} ->
            %{
              playlist_id: playlist.id,
              track_id: id,
              position: pos,
              inserted_at: now,
              updated_at: now
            }
          end)

        {_count, results} =
          Repo.insert_all(
            PlaylistItem,
            rows,
            on_conflict: {:replace, [:position, :updated_at]},
            conflict_target: [:id],
            returning: true
          )

        results
      end

    update_playlist_track_count(playlist)

    {:ok,
     %{
       added: added || [],
       moved: moved || [],
       removed: removed || []
     }}
  end

  defp update_playlist_track_count(playlist) do
    subquery =
      from(pi in PlaylistItem,
        where: pi.playlist_id == ^playlist.id,
        select: %{playlist_id: pi.playlist_id, count: count(pi.id)}
      )

    from(p in Playlist,
      left_join: s in subquery(subquery),
      on: p.id == s.playlist_id,
      where: p.id == ^playlist.id,
      update: [set: [track_count: coalesce(s.count, 0)]]
    )
    |> Repo.update_all([])
  end

  defp find_duplicates(list) do
    list
    |> Enum.frequencies()
    |> Enum.filter(fn {_item, count} -> count >= 2 end)
    |> Enum.map(fn {item, _count} -> item end)
  end

  defp find_duplicates_by(list1, list2, key) do
    keys2 = MapSet.new(list2, &Map.get(&1, key))
    Enum.filter(list1, fn m -> MapSet.member?(keys2, Map.get(m, key)) end)
  end
end
