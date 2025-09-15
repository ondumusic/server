defmodule MusicBox.Albums.Artwork do
  use MusicBox.Schema

  alias MusicBox.Albums.Album

  @fetchers ~w(embedded custom_api music_brainz)a

  @primary_key {:album_id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id
  schema "album_artworks" do
    belongs_to :album, Album, define_field: false

    field :path, :string
    field :fetcher, Ecto.Enum, values: @fetchers
    field :last_fetch_attempt, :utc_datetime
  end

  def changeset(%__MODULE__{} = struct, attrs) do
    struct
    |> cast(attrs, [
      :path,
      :fetcher,
      :last_fetch_attempt
    ])
  end

  def fetchers, do: @fetchers
end
