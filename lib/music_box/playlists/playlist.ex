defmodule MusicBox.Playlists.Playlist do
  @moduledoc false

  use MusicBox.Schema

  alias MusicBox.Playlists.PlaylistItem

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "playlists" do
    field :name, :string
    field :track_count, :integer, default: 0

    has_many :items, PlaylistItem, preload_order: [asc: :position]

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

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = struct, attrs) do
    struct
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
