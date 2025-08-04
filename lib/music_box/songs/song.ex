defmodule MusicBox.Songs.Song do
  use Ecto.Schema
  import Ecto.Changeset

  alias MusicBox.Artists.Artist
  alias MusicBox.Albums.Album
  alias MusicBox.Files.File

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "songs" do
    field :name, :string
    field :duration, :float
    field :track, :integer

    belongs_to :artist, Artist
    belongs_to :album, Album
    belongs_to :file, File

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(song, attrs) do
    song
    |> cast(attrs, [:artist_id, :album_id, :track, :name, :duration])
    |> validate_required([:name, :duration])
    |> unique_constraint(:file_id)
  end
end
