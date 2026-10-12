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

  def get_entities(params) do
    cursor = Map.get(params, "cursor") |> decode_cursor()
    limit = Map.get(params, "limit")

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

  def encode_cursor(result, params \\ %{}) do
    prev_cursor = Map.get(params, "cursor") |> decode_cursor()
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

  def decode_cursor(nil), do: %{}

  def decode_cursor("v1-" <> cursor) do
    # NOTE: todo maybe add error handling
    cursor
    |> Base.url_decode64!()
    |> JSON.decode!()
  end

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
