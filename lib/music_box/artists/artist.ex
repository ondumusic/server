defmodule MusicBox.Artists.Artist do
  use Ecto.Schema
  import Ecto.Changeset

  alias MusicBox.Albums.Album
  alias MusicBox.Songs.Song

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "artists" do
    field :name, :string

    has_many :albums, Album
    has_many :songs, Song

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(artist, attrs) do
    artist
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
