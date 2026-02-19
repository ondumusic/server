defmodule MusicBox.Search do
  @moduledoc false

  alias MusicBox.Albums.Album
  alias MusicBox.Artists.Artist
  alias MusicBox.Repo
  alias MusicBox.Tracks.Track

  import Ecto.Query

  # @type t :: %__MODULE__{}

  # @spec search(String.t()) :: [t()]
  def search(query) do
    query = parse_query(query)

    search(query, [
      :artist,
      :album,
      :track
    ])
  end

  defp search(query, _sources, results \\ [])
  defp search(_query, [], results), do: results

  defp search(query, [:artist | sources], results) do
    items =
      from(s in "artists_fts",
        join: a in Artist,
        on: a.rowid == s.rowid,
        select: %{
          rank:
            fragment("""
            bm25(artists_fts,
              'name', 20.0,
              'slug', 10.0
            )
            """),
          result: a
        },
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
      |> Repo.all()

    search(query, sources, results ++ items)
  end

  defp search(query, [:album | sources], results) do
    items =
      from(s in "albums_fts",
        join: a in Album,
        on: a.rowid == s.rowid,
        select: %{
          rank:
            fragment("""
            bm25(albums_fts,
              'name', 20.0,
              'slug', 10.0
            )
            """),
          result: a
        },
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
      |> Repo.all()

    search(query, sources, results ++ items)
  end

  defp search(query, [:track | sources], results) do
    items =
      from(s in "tracks_fts",
        join: a in Track,
        on: a.rowid == s.rowid,
        select: %{
          rank:
            fragment("""
            bm25(tracks_fts,
              'name', 20.0,
              'slug', 10.0
            )
            """),
          result: a
        },
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
      |> Repo.all()

    search(query, sources, results ++ items)
  end

  defp parse_query(query) do
    query
    |> String.split(~r/\s+/)
    |> Enum.map_join(" AND ", &"(#{&1} OR #{&1}*)")
  end
end
