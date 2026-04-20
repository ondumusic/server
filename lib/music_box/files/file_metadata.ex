defmodule MusicBox.Files.FileMetadata do
  @moduledoc false

  use MusicBox.Schema

  @type t :: %__MODULE__{}

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

    # Audio stream details
    field :bitrate, :integer
    field :sample_rate, :integer
    field :audio_channels, :integer
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(metadata, attrs) do
    metadata
    |> cast(attrs, [
      :artist,
      :album,
      :album_artist,
      :compilation,
      :title,
      :disc,
      :track,
      :release_year,
      :duration,
      :genres,
      :bitrate,
      :sample_rate,
      :audio_channels
    ])
  end
end
