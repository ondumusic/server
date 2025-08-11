defmodule MusicBox.Artists.Artist do
  use Ecto.Schema

  alias MusicBox.Tracks.Track
  alias MusicBox.Albums.Album

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "artists" do
    field :name, :string
    field :slug, :string

    field :album_count, :integer, virtual: true

    has_many :albums, Album
    has_many :tracks, Track

    timestamps(type: :utc_datetime)
  end
end
