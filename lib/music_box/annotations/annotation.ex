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

  alias MusicBox.Albums.Album
  alias MusicBox.Artists.Artist

  @type t :: %__MODULE__{}

  # We currently only support annotations for these entities.
  @entity_schemas %{
    artists: Artist,
    albums: Album
  }
  @entity_types Map.keys(@entity_schemas)

  # Something like "musicbrainz" or "my-script.cache".
  @namespace_format ~r/\A[a-z0-9._-]{1,64}\z/

  # 4KB felt like a generous enough limit for most use cases.
  @max_data_size 4 * 1024

  @primary_key false
  schema "annotations" do
    field :namespace, :string, primary_key: true
    field :entity_type, Ecto.Enum, values: @entity_types, primary_key: true
    field :entity_id, Ecto.UUID, primary_key: true

    field :data, :map

    timestamps(type: :utc_datetime)
  end

  # NOTE: data is not marked as required because it could be nilified,
  # which results in a delete in the context module.
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(annotation, attrs) do
    annotation
    |> cast(attrs, [:namespace, :entity_type, :entity_id, :data])
    |> validate_required([:namespace, :entity_type, :entity_id])
    |> validate_format(:namespace, @namespace_format)
    |> validate_data(attrs)
  end

  defp validate_data(changeset, attrs) do
    cond do
      not (is_map_key(attrs, "data") or is_map_key(attrs, :data)) ->
        add_error(changeset, :data, "can't be missing")

      data = get_change(changeset, :data) ->
        if byte_size(JSON.encode!(data)) > @max_data_size,
          do: add_error(changeset, :data, "is too large"),
          else: changeset

      true ->
        changeset
    end
  end

  @spec entity_types() :: [atom()]
  def entity_types, do: @entity_types

  @doc "Returns the schema for an entity type, e.g. `Artist` for `:artists`"
  @spec entity_schema(atom()) :: module()
  def entity_schema(entity_type), do: Map.fetch!(@entity_schemas, entity_type)

  @spec valid_namespace?(term()) :: boolean()
  def valid_namespace?(namespace),
    do: is_binary(namespace) and Regex.match?(@namespace_format, namespace)
end
