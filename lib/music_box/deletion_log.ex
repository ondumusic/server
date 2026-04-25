defmodule MusicBox.DeletionLog do
  @moduledoc false
  use MusicBox.Schema

  @primary_key false
  schema "deletion_log" do
    field :entity_type, Ecto.Enum,
      values: ~w(file track artist album playlist playlist_item)a,
      primary_key: true

    field :entity_id, :binary_id, primary_key: true
    field :metadata, :map, default: %{}
    field :deleted_at, :utc_datetime
  end
end
