defmodule Ondu.Playlists.Playlist do
  @moduledoc false

  use Ondu.Schema

  alias Ondu.Playlists.PlaylistItem

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "playlists" do
    field :name, :string
    field :track_count, :integer, default: 0
    field :is_folder, :boolean, default: false

    has_many :items, PlaylistItem, preload_order: [asc: :position]
    belongs_to :playlist, __MODULE__, foreign_key: :parent_id

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
    |> cast(attrs, [:name, :is_folder, :parent_id])
    |> validate_required([:name])
    |> validate_folder()
    |> validate_parent()
  end

  defp validate_folder(changeset) do
    new_is_folder = get_change(changeset, :is_folder)

    new_entry? =
      case changeset.data do
        %{id: id} -> not is_binary(id)
        _ -> true
      end

    if not new_entry? and is_boolean(new_is_folder) do
      add_error(changeset, :is_folder, "cannot change existing playlist into folder")
    else
      changeset
    end
  end

  defp validate_parent(changeset) do
    if parent_id = get_change(changeset, :parent_id) do
      do_validate_parent(changeset, parent_id)
    else
      changeset
    end
  end

  defp do_validate_parent(changeset, parent_id) do
    prepare_changes(changeset, fn changeset ->
      case changeset.repo.get(__MODULE__, parent_id) do
        nil -> add_error(changeset, :parent_id, "does not exist")
        %{is_folder: true} -> changeset
        _ -> add_error(changeset, :parent_id, "is not a folder")
      end
    end)
  end
end
