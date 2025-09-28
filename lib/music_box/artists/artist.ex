defmodule MusicBox.Artists.Artist do
  @moduledoc false

  use MusicBox.Schema

  alias MusicBox.Albums.Album
  alias MusicBox.Tracks.Track

  @type t() :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "artists" do
    field :name, :string
    field :slug, :string

    field :album_count, :integer, virtual: true

    has_many :albums, Album
    has_many :tracks, Track

    timestamps(type: :utc_datetime)
  end

  def preloaded(query \\ nil) do
    query =
      if query,
        do: query,
        else: from(a in __MODULE__, as: :artist)

    album_count_query =
      from(al in Album,
        where: al.artist_id == parent_as(:artist).id,
        select: count(al.artist_id)
      )

    query
    |> select_merge(%{
      album_count: subquery(album_count_query)
    })
  end
end
