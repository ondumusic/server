defmodule MusicBox.Albums.Album do
  use MusicBox.Schema

  alias MusicBox.Artists.Artist
  alias MusicBox.Tracks.Track

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "albums" do
    field :name, :string
    field :slug, :string
    field :compilation, :boolean
    field :release_year, :integer
    field :is_unknown, :boolean, default: false

    belongs_to :artist, Artist
    has_many :tracks, Track, preload_order: [asc: :disc, asc_nulls_last: :number, asc: :name]

    timestamps(type: :utc_datetime)
  end

  def preloaded(query \\ nil) do
    query =
      if query,
        do: query,
        else: from(al in __MODULE__, as: :album)

    query
    |> join(:inner, [album: al], a in assoc(al, :artist), as: :artist)
    |> preload([artist: a], artist: a, tracks: [:artist])
  end
end
