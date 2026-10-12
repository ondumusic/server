defmodule Ondu.Tracks.Track do
  @moduledoc false

  use Ondu.Schema

  alias Ondu.Albums.Album
  alias Ondu.Artists.Artist
  alias Ondu.Files.File

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tracks" do
    field :name, :string
    field :slug, :string
    field :duration, :float
    field :number, :integer
    field :disc, :integer, default: 1
    field :play_count, :integer, default: 0
    field :last_played_at, :utc_datetime

    belongs_to :artist, Artist
    belongs_to :album, Album
    belongs_to :file, File

    timestamps(type: :utc_datetime)
  end

  @spec preloaded(Ecto.Queryable.t() | nil) :: Ecto.Queryable.t()
  def preloaded(query \\ nil) do
    query =
      if query,
        do: query,
        else: from(t in __MODULE__, as: :track)

    query
    |> join(:inner, [track: t], a in assoc(t, :artist), as: :artist)
    |> join(:inner, [track: t], al in assoc(t, :album), as: :album)
    |> join(:inner, [album: a], ala in assoc(a, :artist), as: :album_artist)
    |> join(:inner, [track: t], f in assoc(t, :file), as: :file)
    |> preload([artist: a, album: al, album_artist: ala, file: f],
      artist: {a, :artwork},
      album: {al, [:artwork, artist: ala]},
      file: f
    )
  end
end
