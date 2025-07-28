defmodule MusicBox.Songs.Song do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "songs" do
    field :name, :string
    field :artist_id, Ecto.UUID
    field :album_id, Ecto.UUID
    field :duration, :float

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(song, attrs) do
    song
    |> cast(attrs, [:artist_id, :album_id, :name, :duration])
    |> validate_required([:artist_id, :album_id, :name, :duration])
  end
end
