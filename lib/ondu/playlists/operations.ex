defmodule Ondu.Playlists.Operations do
  @moduledoc false

  import Phoenix.Channel.Server, only: [broadcast: 4]

  alias Ondu.FractionalIndex
  alias Ondu.Playlists.{Playlist, PlaylistItem}
  alias Ondu.Repo
  alias Ondu.Tracks.Track

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
          | {:error, {:duplicate_items, [String.t()]}}
          | {:error, {:invalid_positions, [position()]}}
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
         :ok <- validate_unique_items(Enum.map(moves, & &1["item_id"])),
         :ok <- validate_unique_items(removes),
         :ok <- validate_positions(adds, moves),
         :ok <- validate_tracks(adds),
         existing_items <- get_existing_items(playlist, combined_ids),
         :ok <- validate_items(existing_items, combined_ids),
         {:ok, %{adds: adds, moves: moves}} <- ensure_unique_positions(playlist, adds, moves) do
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

  defp validate_unique_items(items) do
    duplicates = find_duplicates(items)

    if duplicates == [] do
      :ok
    else
      {:error, {:duplicate_items, duplicates}}
    end
  end

  defp validate_positions(adds, moves) do
    invalid_positions =
      List.flatten([adds, moves])
      |> Enum.map(&Map.get(&1, "position"))
      |> Enum.flat_map(fn position ->
        case FractionalIndex.validate(position) do
          :ok -> []
          {:error, _} -> [position]
        end
      end)

    if invalid_positions == [] do
      :ok
    else
      {:error, {:invalid_positions, invalid_positions}}
    end
  end

  # Positions are unique within a playlist. A requested position that is taken,
  # by an existing item or by an earlier operation in this request, gets a new
  # position right after it (the response contains the positions used).
  defp ensure_unique_positions(playlist, adds, moves) do
    requested = Enum.map(adds ++ moves, & &1["position"])

    taken =
      from(i in PlaylistItem,
        where: i.playlist_id == ^playlist.id and i.position in ^requested,
        select: i.position
      )
      |> Repo.all()

    if taken == [] and find_duplicates(requested) == [] do
      {:ok, %{adds: adds, moves: moves}}
    else
      used =
        from(i in PlaylistItem,
          where: i.playlist_id == ^playlist.id,
          order_by: [asc: i.position],
          select: i.position
        )
        |> Repo.all()

      {adds, used} = fix_positions(adds, used)
      {moves, _used} = fix_positions(moves, used)
      {:ok, %{adds: adds, moves: moves}}
    end
  end

  # Used positions are kept sorted, to find the next position after a taken one.
  defp fix_positions(items, used) do
    Enum.map_reduce(items, used, fn item, used ->
      position = item["position"]

      position =
        if position in used,
          do: generate_new_position(position, Enum.find(used, &(&1 > position)), used),
          else: position

      {Map.put(item, "position", position), Enum.sort([position | used])}
    end)
  end

  defp generate_new_position(before_key, after_key, used) do
    position = FractionalIndex.generate_key_between(before_key, after_key)

    if position in used do
      next_after = Enum.find(used, fn p -> p > position end)
      generate_new_position(position, next_after, used)
    else
      position
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

        deleted =
          Enum.map(results, fn playlist_item_id ->
            %{entityType: "playlistItem", entityId: playlist_item_id}
          end)

        broadcast(Ondu.PubSub, "library:sync", "deleted", %{
          deletions: deleted
        })

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

        broadcast(Ondu.PubSub, "library:sync", "processed", %{
          playlist_items: Enum.map(results, & &1.id)
        })

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

        broadcast(Ondu.PubSub, "library:sync", "processed", %{
          playlist_items: Enum.map(results, & &1.id)
        })

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
    started_at = DateTime.utc_now()

    subquery =
      from(pi in PlaylistItem,
        where: pi.playlist_id == ^playlist.id,
        select: %{playlist_id: coalesce(pi.playlist_id, ^playlist.id), count: count(pi.id)}
      )

    {count, _} =
      from(p in Playlist,
        left_join: s in subquery(subquery),
        on: p.id == s.playlist_id,
        where: p.id == ^playlist.id,
        where: p.track_count != coalesce(s.count, 0) or is_nil(p.track_count),
        update: [set: [track_count: coalesce(s.count, 0), updated_at: ^started_at]]
      )
      |> Repo.update_all([])

    if count > 0 do
      broadcast(Ondu.PubSub, "library:sync", "processed", %{
        playlists: [playlist.id]
      })
    end
  end

  defp find_duplicates(list) do
    list
    |> Enum.frequencies()
    |> Enum.filter(fn {_item, count} -> count >= 2 end)
    |> Enum.map(fn {item, _count} -> item end)
  end
end
