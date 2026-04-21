defmodule MusicBox.Playlists.PlaylistItem do
  @moduledoc false

  use MusicBox.Schema

  alias MusicBox.Playlists.Playlist
  alias MusicBox.Tracks.Track

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "playlists" do
    field :position, :string
    belongs_to :playlist, Playlist
    belongs_to :track, Track

    timestamps(type: :utc_datetime)
  end

  @spec preloaded(Ecto.Queryable.t() | nil) :: Ecto.Queryable.t()
  def preloaded(query \\ nil) do
    query =
      if query,
        do: query,
        else: from(pi in __MODULE__, as: :playlist_item)

    query
  end
end
