defmodule MusicBox.Files.File do
  @moduledoc false

  use MusicBox.Schema

  alias MusicBox.Files.FileMetadata
  alias MusicBox.Tracks.Track

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "files" do
    field :path, :string
    field :size, :integer
    field :type, Ecto.Enum, values: ~w(aac aiff m4a mp3 opus ogg flac wav)a

    embeds_one :metadata, FileMetadata, on_replace: :delete

    has_one :track, Track

    field :last_scanned_at, :utc_datetime
    field :last_modified_at, :utc_datetime
    timestamps(type: :utc_datetime)
  end

  @spec mimetype(t()) :: String.t()
  def mimetype(%__MODULE__{type: type}) do
    case type do
      :aac -> "audio/aac"
      :aiff -> "audio/aiff"
      :flac -> "audio/flac"
      :m4a -> "audio/mp4"
      :mp3 -> "audio/mpeg"
      :ogg -> "audio/ogg"
      :opus -> "audio/opus"
      :wav -> "audio/wav"
    end
  end
end
