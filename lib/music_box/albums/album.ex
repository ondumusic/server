defmodule MusicBox.Albums.Album do
  use Ecto.Schema

  alias MusicBox.Artists.Artist
  alias MusicBox.Tracks.Track

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "albums" do
    field :name, :string
    field :slug, :string
    field :compilation, :boolean
    field :release_year, :integer

    belongs_to :artist, Artist
    has_many :tracks, Track, preload_order: [asc: :disc, asc_nulls_last: :number, asc: :name]

    timestamps(type: :utc_datetime)
  end
end
