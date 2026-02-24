defmodule MusicBox.Tracks.Track do
  @moduledoc false

  use MusicBox.Schema

  alias MusicBox.Albums.Album
  alias MusicBox.Artists.Artist
  alias MusicBox.Files.File

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tracks" do
    field :name, :string
    field :slug, :string
    field :duration, :float
    field :number, :integer
    field :disc, :integer, default: 1

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
    |> join(:inner, [track: t], f in assoc(t, :file), as: :file)
    |> preload([artist: a, album: al, file: f], artist: a, album: {al, :artwork}, file: f)
  end
end
