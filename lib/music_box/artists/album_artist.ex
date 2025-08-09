defmodule MusicBox.Artists.AlbumArtist do
  use Ecto.Schema
  import Ecto.Changeset

  alias MusicBox.Albums.Album

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "album_artists" do
    field :name, :string
    field :slug, :string
    field :album_count, :integer, virtual: true, default: 0

    has_many :albums, Album

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(artist, attrs) do
    artist
    |> cast(attrs, [:name, :slug])
    |> validate_required([:name])
    |> unique_constraint(:name)
    |> unique_constraint(:slug)
  end
end
