defmodule MusicBox.Files.File do
  use Ecto.Schema

  alias MusicBox.Tracks.Track
  alias MusicBox.Files.FileMetadata

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "files" do
    field :path, :string
    field :checksum, :string
    field :size, :integer
    field :type, Ecto.Enum, values: ~w(m4a mp3 opus ogg flac wav)a

    embeds_one :metadata, FileMetadata, on_replace: :delete

    has_one :track, Track

    field :last_scanned_at, :utc_datetime
    field :last_modified_at, :utc_datetime
    timestamps(type: :utc_datetime)
  end
end
