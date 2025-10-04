defmodule MusicBox.Albums.Artwork do
  @moduledoc false

  use MusicBox.Schema

  alias MusicBox.Albums.Album

  @type t :: %__MODULE__{}

  @type fetcher :: :embedded | :custom_api | :music_brainz
  @fetchers ~w(embedded custom_api music_brainz)a

  @primary_key {:album_id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id
  schema "album_artworks" do
    belongs_to :album, Album, define_field: false

    field :path, :string
    field :fetcher, Ecto.Enum, values: @fetchers
    field :last_fetch_attempt, :utc_datetime
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = struct, attrs) do
    struct
    |> cast(attrs, [
      :path,
      :fetcher,
      :last_fetch_attempt
    ])
  end

  @spec fetchers() :: [fetcher()]
  def fetchers, do: @fetchers
end
