defmodule MusicBox.Files.File do
  use Ecto.Schema
  import Ecto.Changeset

  alias MusicBox.Songs.Song
  alias MusicBox.Files.FileMetadata

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "files" do
    field :path, :string
    field :checksum, :string

    embeds_one :metadata, FileMetadata, on_replace: :delete

    has_one :song, Song

    field :last_scanned_at, :utc_datetime
    field :last_modified_at, :utc_datetime
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(file, attrs) do
    file
    |> cast(attrs, [:path, :last_scanned_at, :last_modified_at, :checksum])
    |> validate_required([:path, :last_scanned_at, :last_modified_at, :checksum])
    |> cast_embed(:metadata)
    |> unique_constraint(:path)
  end
end
