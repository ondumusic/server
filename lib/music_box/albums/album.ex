defmodule MusicBox.Albums.Album do
  use Ecto.Schema
  import Ecto.Changeset

  alias MusicBox.Artists.Artist
  alias MusicBox.Songs.Song

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "albums" do
    field :name, :string
    field :compilation, :boolean
    field :release_year, :integer

    belongs_to :artist, Artist
    has_many :songs, Song, preload_order: [asc_nulls_last: :track, asc: :name]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(album, attrs) do
    album
    |> cast(attrs, [:artist_id, :name, :compilation, :release_year])
    |> validate_required([:artist_id, :compilation, :name])
    |> unique_constraint([:artist_id, :name])
  end
end
