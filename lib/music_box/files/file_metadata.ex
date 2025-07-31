defmodule MusicBox.Files.FileMetadata do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :artist, :string
    field :album, :string
    field :title, :string
    field :track, :integer
    field :release_year, :integer
    field :duration, :float
    field :genres , {:array, :string}
  end

  def changeset(metadata, params) do
    metadata
    |> cast(params, [:artist, :album, :title, :track, :release_year, :duration, :genres])
  end
end
