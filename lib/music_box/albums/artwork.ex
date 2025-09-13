defmodule MusicBox.Albums.Artwork do
  use MusicBox.Schema

  alias MusicBox.Albums.Album

  @fetchers ~w(embedded)a

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

  def preloaded(query \\ nil) do
    query =
      if query,
        do: query,
        else: from(al in __MODULE__, as: :album)

    query
    |> join(:inner, [album: al], a in assoc(al, :artist), as: :artist)
    |> preload([artist: a], artist: a, tracks: ^Track.preloaded())
  end
end
