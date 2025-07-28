defmodule MusicBox.Files.File do
  use Ecto.Schema
  import Ecto.Changeset

  alias MusicBox.Songs.Song

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "files" do
    field :path, :string
    field :last_scanned_at, :utc_datetime

    has_one :song, Song

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(file, attrs) do
    file
    |> cast(attrs, [:path, :last_scanned_at])
    |> validate_required([:path, :last_scanned_at])
  end
end
