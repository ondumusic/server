defmodule Ondu.Sync do
  @moduledoc false

  alias Ondu.Albums.Album
  alias Ondu.Artists.Artist
  alias Ondu.DeletionLog
  alias Ondu.Playlists.Playlist
  alias Ondu.Playlists.PlaylistItem
  alias Ondu.Repo
  alias Ondu.Tracks.Track

  import Ecto.Query

  @default_limit 100
  @max_limit 500

  def get_entities(cursor, limit \\ nil) do
    %{
      artists: get_new_entities(Artist.preloaded(), cursor["artists"], limit: limit),
      albums: get_new_entities(Album.preloaded(), cursor["albums"], limit: limit),
      tracks: get_new_entities(Track.preloaded(), cursor["tracks"], limit: limit),
      playlists: get_new_entities(Playlist.preloaded(), cursor["playlists"], limit: limit),
      playlist_items:
        get_new_entities(PlaylistItem.preloaded(), cursor["playlist_items"], limit: limit),
      deletions:
        get_new_entities(DeletionLog, cursor["deletions"],
          limit: limit,
          pk_field: :entity_id,
          date_field: :deleted_at
        )
    }
  end

  def encode_cursor(result, prev_cursor \\ %{}) do
    version = 1

    cursor =
      Enum.reduce(result, %{}, fn
        {k, %{entries: []}}, acc ->
          case Map.get(prev_cursor, to_string(k)) do
            [_date, _last_id] = old_value -> Map.put(acc, k, old_value)
            _ -> acc
          end

        {k, %{entries: v}}, acc ->
          case List.last(v) do
            %{deleted_at: date} = last -> Map.put(acc, k, [date, last.entity_id])
            %{updated_at: date} = last -> Map.put(acc, k, [date, last.id])
          end
      end)
      |> JSON.encode!()
      |> Base.url_encode64()

    "v#{version}-#{cursor}"
  end

  def decode_cursor(nil), do: {:ok, %{}}

  def decode_cursor("v1-" <> encoded) do
    with {:ok, json} <- Base.url_decode64(encoded),
         {:ok, %{} = cursor} <- JSON.decode(json),
         true <- Enum.all?(cursor, &valid_position?/1) do
      {:ok, cursor}
    else
      _ -> {:error, :invalid_cursor}
    end
  end

  def decode_cursor(_cursor), do: {:error, :invalid_cursor}

  defp valid_position?({_key, [date, id]}) when is_binary(date) do
    with {:ok, _date, _offset} <- DateTime.from_iso8601(date),
         {:ok, _id} <- Ecto.UUID.cast(id) do
      true
    else
      _ -> false
    end
  end

  defp valid_position?(_position), do: false

  def parse_limit(limit) when is_binary(limit) do
    case Integer.parse(limit) do
      {limit, ""} when limit > 0 -> min(limit, @max_limit)
      _ -> @default_limit
    end
  end

  def parse_limit(_limit), do: @default_limit

  defp get_new_entities(mod, cursor, opts) do
    limit = Keyword.get(opts, :limit) || @default_limit
    pk_field = Keyword.get(opts, :pk_field, :id)
    date_field = Keyword.get(opts, :date_field, :updated_at)

    query =
      from(m in mod,
        order_by: [asc: field(m, ^date_field), asc: field(m, ^pk_field)],
        limit: ^(limit + 1)
      )

    query =
      case cursor do
        [last_date, last_id] ->
          where(
            query,
            [m],
            field(m, ^date_field) > ^last_date or
              (field(m, ^date_field) == ^last_date and
                 field(m, ^pk_field) > ^last_id)
          )

        _ ->
          query
      end

    entries = Repo.all(query)
    has_more? = length(entries) > limit

    %{
      entries: Enum.slice(entries, 0, limit),
      has_more?: has_more?
    }
  end
end
