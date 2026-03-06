defmodule MusicBox.Sync do
  @moduledoc false

  alias MusicBox.Albums.Album
  alias MusicBox.Artists.Artist
  alias MusicBox.Repo
  alias MusicBox.Tracks.Track

  import Ecto.Query

  @default_limit 100

  def get_entities(params) do
    cursor = Map.get(params, "cursor") |> decode_cursor()
    limit = Map.get(params, "limit")

    %{
      artists: get_new_entities(Artist, cursor["artists"], limit: limit),
      albums: get_new_entities(Album.preloaded(), cursor["albums"], limit: limit),
      tracks: get_new_entities(Track.preloaded(), cursor["tracks"], limit: limit)
    }
  end

  def encode_cursor(result) do
    version = 1

    cursor =
      Enum.reduce(result, %{}, fn
        {_k, %{entries: []}}, acc ->
          acc

        {k, %{entries: v}}, acc ->
          last = List.last(v)
          Map.put(acc, k, [last.updated_at, last.id])
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

    query =
      from(m in mod,
        order_by: [asc: :updated_at, asc: :id],
        limit: ^(limit + 1)
      )

    query =
      case cursor do
        [updated_at, id] ->
          where(
            query,
            [m],
            m.updated_at >= ^updated_at and
              m.id != ^id
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
