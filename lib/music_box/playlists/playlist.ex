defmodule MusicBox.Playlists.Playlist do
  @moduledoc false

  use MusicBox.Schema

  alias MusicBox.Playlists.PlaylistItem

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "playlists" do
    field :name, :string
    field :track_count, :integer

    has_many :items, PlaylistItem

    timestamps(type: :utc_datetime)
  end

  @spec preloaded(Ecto.Queryable.t() | nil) :: Ecto.Queryable.t()
  def preloaded(query \\ nil) do
    query =
      if query,
        do: query,
        else: from(p in __MODULE__, as: :playlist)

    query
  end
end
