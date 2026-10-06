defmodule MusicBox.Annotations.Annotation do
  @moduledoc """
  Annotations contain simple data inside namespaces.

  The idea is that any scripts/tools using the API can persist data in the
  database as well. The library and official apps don't do anything with this.

  For example if you write a script that looks up artists on MusicBrainz and
  you want to persist the MBID for future reference, without having to deal
  with a secondary database for the script itself, this is the way to do it.

  Namespaces are mostly to isolate for different scripts/tools.
  """

  use MusicBox.Schema

  @type t :: %__MODULE__{}

  @entity_types ~w(artists albums)a

  @primary_key false
  schema "annotations" do
    field :namespace, :string, primary_key: true
    field :entity_type, Ecto.Enum, values: @entity_types, primary_key: true
    field :entity_id, :binary_id, primary_key: true

    field :data, :map

    timestamps(type: :utc_datetime)
  end

  @spec entity_types() :: [atom()]
  def entity_types, do: @entity_types
end
