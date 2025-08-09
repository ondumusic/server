defmodule MusicBox.Files.FileMetadata do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :artist, :string
    field :album, :string
    field :album_artist, :string
    field :title, :string
    field :disc, :integer
    field :track, :integer
    field :release_year, :integer
    field :compilation, :boolean
    field :duration, :float
    field :genres, {:array, :string}
  end

  def changeset(metadata, params) do
    metadata
    |> cast(params, [
      :artist,
      :album,
      :album_artist,
      :compilation,
      :title,
      :disc,
      :track,
      :release_year,
      :duration,
      :genres
    ])
  end
end
