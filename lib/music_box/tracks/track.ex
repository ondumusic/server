defmodule MusicBox.Tracks.Track do
  use MusicBox.Schema

  alias MusicBox.Artists.Artist
  alias MusicBox.Albums.Album
  alias MusicBox.Files.File

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tracks" do
    field :name, :string
    field :duration, :float
    field :number, :integer
    field :disc, :integer, default: 1

    belongs_to :artist, Artist
    belongs_to :album, Album
    belongs_to :file, File

    timestamps(type: :utc_datetime)
  end
end
