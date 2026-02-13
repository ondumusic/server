defmodule MusicBox.Albums.Album do
  @moduledoc false

  use MusicBox.Schema

  alias MusicBox.Albums.Artwork
  alias MusicBox.Artists.Artist
  alias MusicBox.Tracks.Track

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "albums" do
    field :name, :string
    field :slug, :string
    field :compilation, :boolean
    field :release_year, :integer
    field :is_unknown, :boolean, default: false
    field :sort_name, :string

    belongs_to :artist, Artist
    has_many :tracks, Track, preload_order: [asc: :disc, asc_nulls_last: :number, asc: :name]
    has_one :artwork, Artwork

    timestamps(type: :utc_datetime)
  end

  @spec preloaded(Ecto.Queryable.t() | nil) :: Ecto.Queryable.t()
  def preloaded(query \\ nil) do
    query =
      if query,
        do: query,
        else: from(al in __MODULE__, as: :album)

    query
    |> join(:inner, [album: al], a in assoc(al, :artist), as: :artist)
    |> join(:left, [album: al], art in assoc(al, :artwork), as: :artwork)
    |> preload([artist: a, artwork: art], artist: a, artwork: art, tracks: ^Track.preloaded())
  end
end
