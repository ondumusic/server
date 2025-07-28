defmodule MusicBox.Albums.Album do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "albums" do
    field :name, :string
    field :artist_id, Ecto.UUID
    field :release_year, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(album, attrs) do
    album
    |> cast(attrs, [:artist_id, :name, :release_year])
    |> validate_required([:artist_id, :name, :release_year])
  end
end
