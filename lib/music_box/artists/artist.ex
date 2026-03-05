defmodule MusicBox.Artists.Artist do
  @moduledoc false

  use MusicBox.Schema

  alias MusicBox.Albums.Album
  alias MusicBox.Tracks.Track

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "artists" do
    field :name, :string
    field :slug, :string
    field :sort_name, :string

    field :album_count, :integer

    has_many :albums, Album
    has_many :tracks, Track

    timestamps(type: :utc_datetime)
  end

  @spec preloaded(Ecto.Queryable.t() | nil) :: Ecto.Queryable.t()
  def preloaded(query \\ nil) do
    query =
      if query,
        do: query,
        else: from(a in __MODULE__, as: :artist)

    query
  end
end
