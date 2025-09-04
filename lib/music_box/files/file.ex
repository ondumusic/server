defmodule MusicBox.Files.File do
  use MusicBox.Schema

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

  def mimetype(%__MODULE__{type: type}) do
    case type do
      :m4a -> "audio/mp4"
      :mp3 -> "audio/mpeg"
      :opus -> "audio/ogg"
      :ogg -> "audio/ogg"
      :flac -> "audio/flac"
      :wav -> "audio/wav"
    end
  end
end
