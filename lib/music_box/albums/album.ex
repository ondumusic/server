defmodule MusicBox.Albums.Album do
  use Ecto.Schema
  import Ecto.Changeset

  alias MusicBox.Artists.AlbumArtist
  alias MusicBox.Songs.Song

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "albums" do
    field :name, :string
    field :compilation, :boolean
    field :release_year, :integer

    belongs_to :album_artist, AlbumArtist
    has_many :songs, Song, preload_order: [asc: :disc, asc_nulls_last: :track, asc: :name]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(album, attrs) do
    album
    |> cast(attrs, [:album_artist_id, :name, :compilation, :release_year])
    |> validate_required([:album_artist_id, :compilation, :name])
    |> unique_constraint([:album_artist_id, :name])
  end
end
