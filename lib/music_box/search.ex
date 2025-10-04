defmodule MusicBox.Search do
  @moduledoc false

  use MusicBox.Schema

  alias MusicBox.Albums.Album
  alias MusicBox.Artists.Artist
  alias MusicBox.Repo
  alias MusicBox.Tracks.Track

  import Ecto.Query

  @primary_key false
  schema "search" do
    field :rank, :float

    belongs_to :artist, Artist
    belongs_to :album, Album
    belongs_to :track, Track
  end

  @type t :: %__MODULE__{}

  @spec search(String.t()) :: [t()]
  def search(query) do
    query = parse_query(query)

    from(s in __MODULE__,
      where: fragment("search match ?", ^query),
      select: %__MODULE__{
        rank:
          fragment("""
          bm25(search,
            'track_name', 20.0,
            'artist_name', 10.0
          )
          """),
        track_id: type(s.track_id, :binary_id),
        artist_id: type(s.artist_id, :binary_id),
        album_id: type(s.album_id, :binary_id)
      },
      order_by: [
        asc:
          fragment("""
          bm25(search,
            'track_name', 20.0,
            'artist_name', 10.0
          )
          """)
      ]
    )
    |> Repo.all()
    |> Repo.preload(
      artist: Artist.preloaded(),
      album: Album.preloaded(),
      track: Track.preloaded()
    )
  end

  defp parse_query(query) do
    query
    |> String.split(~r/\s+/)
    |> Enum.map_join(" AND ", &"(#{&1} OR #{&1}*)")
  end
end
