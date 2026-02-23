defmodule MusicBox.Search do
  @moduledoc false

  alias MusicBox.Albums.Album
  alias MusicBox.Artists.Artist
  alias MusicBox.Repo
  alias MusicBox.Tracks.Track

  import Ecto.Query

  defmodule Result do
    @moduledoc false
    defstruct [:artists, :albums, :tracks]
    @type t :: %__MODULE__{}
  end

  @spec search(String.t(), [Repo.paginate_opts()]) :: [Result.t()]
  def search(query, params \\ %{}) do
    query = parse_query(query)

    search(query, params, [
      :artist,
      :album,
      :track
    ])
  end

  defp search(query, _params, _sources, results \\ %Result{})
  defp search(_query, _params, [], results), do: results

  defp search(query, params, [:artist | sources], results) do
    items =
      from(a in Artist.preloaded(),
        join: s in "artists_fts",
        on: a.rowid == s.rowid,
        where: fragment("artists_fts match ?", ^query),
        order_by: [
          asc:
            fragment("""
            bm25(artists_fts,
              'name', 20.0,
              'slug', 10.0
            )
            """)
        ]
      )
      |> Repo.paginate(params)

    search(query, params, sources, Map.put(results, :artists, items))
  end

  defp search(query, params, [:album | sources], results) do
    items =
      from(a in Album.preloaded(),
        join: s in "albums_fts",
        on: a.rowid == s.rowid,
        where: fragment("albums_fts match ?", ^query),
        order_by: [
          asc:
            fragment("""
            bm25(albums_fts,
              'name', 20.0,
              'slug', 10.0
            )
            """)
        ]
      )
      |> Repo.paginate(params)

    search(query, params, sources, Map.put(results, :albums, items))
  end

  defp search(query, params, [:track | sources], results) do
    items =
      from(a in Track.preloaded(),
        join: s in "tracks_fts",
        on: a.rowid == s.rowid,
        where: fragment("tracks_fts match ?", ^query),
        order_by: [
          asc:
            fragment("""
            bm25(tracks_fts,
              'name', 20.0,
              'slug', 10.0
            )
            """)
        ]
      )
      |> Repo.paginate(params)

    search(query, params, sources, Map.put(results, :tracks, items))
  end

  def parse_query(query) do
    query
    |> String.split(~r/\s+/)
    |> Enum.map_join(" AND ", &"(#{&1} OR #{&1}*)")
  end
end
