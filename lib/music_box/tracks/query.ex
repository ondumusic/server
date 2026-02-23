defmodule MusicBox.Tracks.Query do
  @moduledoc false
  import Ecto.Query

  alias MusicBox.Search
  alias MusicBox.Tracks.IndexForm, as: F
  alias MusicBox.Tracks.Track

  def paginate_tracks(%F{} = form) do
    Track.preloaded()
    |> where_artist(form)
    |> where_album(form)
    |> where_query(form)
    |> set_order_by(form)
  end

  defp where_artist(query, %{artist_id: nil}), do: query

  defp where_artist(query, %{artist_id: artist_id}) do
    where(query, [track: t, album: al], t.artist_id == ^artist_id or al.artist_id == ^artist_id)
  end

  defp where_album(query, %{album_id: nil}), do: query

  defp where_album(query, %{album_id: album_id}) do
    where(query, [track: t], t.album_id == ^album_id)
  end

  defp where_query(query, %{query: nil}), do: query

  defp where_query(query, %{query: search_query}) do
    parsed_query = Search.parse_query(search_query)

    query
    |> join(:inner, [track: t], fts in "tracks_fts", on: fts.rowid == t.rowid, as: :fts)
    |> where(fragment("tracks_fts match ?", ^parsed_query))
    |> exclude(:order_by)
    |> order_by([track: t, album: al, artist: a],
      asc:
        fragment("""
        bm25(tracks_fts,
          'name', 20.0,
          'slug', 10.0
        )
        """),
      asc: a.name,
      desc_nulls_last: al.release_year,
      asc: al.name,
      asc: t.disc,
      asc_nulls_last: t.number,
      asc: t.name
    )
  end

  defp set_order_by(query, %F{sort_by: :random, random_seed: seed}) when not is_nil(seed) do
    order_by(
      query,
      [track: t],
      fragment("(((? * 2654435761) + ?) % 2147483647)", t.rowid, ^seed)
    )
  end

  defp set_order_by(query, _form) do
    order_by(query, [track: t, album: al, artist: a],
      asc: a.name,
      desc_nulls_last: al.release_year,
      asc: al.name,
      asc: t.disc,
      asc_nulls_last: t.number,
      asc: t.name
    )
  end
end
