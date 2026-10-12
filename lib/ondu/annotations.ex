defmodule Ondu.Annotations do
  @moduledoc false

  import Ecto.Changeset
  import Ecto.Query

  alias Ondu.Annotations.Annotation
  alias Ondu.Repo

  # Maximum amount of annotations to be written per batch.
  @max_batch_size 500

  # We limit the total amount of annotations in the database to try and avoid
  # bloating the database. We'll see if this limit makes sense or needs to be
  # tweaked or removed.
  @max_annotations 1_000_000

  @type error ::
          :invalid_namespace
          | :invalid_entity_type
          | :invalid_entries
          | :too_many_entries
          | :too_many_annotations

  @doc "Paginates the annotations for the given entity type and namespace."
  @spec paginate_annotations(String.t(), String.t() | atom(), map()) ::
          {:ok, Repo.page(Annotation.t())} | {:error, error()}
  def paginate_annotations(namespace, entity_type, params \\ %{}) do
    with :ok <- validate_namespace(namespace),
         {:ok, entity_type} <- cast_entity_type(entity_type) do
      page =
        from(a in Annotation,
          where: a.namespace == ^namespace and a.entity_type == ^entity_type,
          order_by: a.entity_id
        )
        |> Repo.paginate(params, default_limit: 500, max_limit: 1000)

      {:ok, page}
    end
  end

  @doc """
  Writes a batch of annotations, it will replace any existing data. Setting the
  `data` to `nil` will remove the annotation. Entities that don't exist are skipped.
  """
  @spec put_annotations(String.t(), String.t() | atom(), [map()]) ::
          {:ok, %{skipped: [Ecto.UUID.t()]}} | {:error, error()}
  def put_annotations(namespace, entity_type, entries) do
    with :ok <- validate_namespace(namespace),
         {:ok, entity_type} <- cast_entity_type(entity_type),
         {:ok, entries} <- cast_entries(namespace, entity_type, entries),
         :ok <- check_total(entries) do
      Repo.transact(fn -> store(namespace, entity_type, entries) end)
    end
  end

  defp validate_namespace(namespace) do
    if Annotation.valid_namespace?(namespace) do
      :ok
    else
      {:error, :invalid_namespace}
    end
  end

  defp cast_entity_type(entity_type) do
    case Enum.find(Annotation.entity_types(), &(to_string(&1) == to_string(entity_type))) do
      nil -> {:error, :invalid_entity_type}
      entity_type -> {:ok, entity_type}
    end
  end

  defp cast_entries(_namespace, _entity_type, entries)
       when is_list(entries) and length(entries) > @max_batch_size,
       do: {:error, :too_many_entries}

  defp cast_entries(namespace, entity_type, entries) when is_list(entries) do
    changesets =
      Enum.map(entries, fn entry ->
        attrs = if is_map(entry), do: entry, else: %{}
        annotation = %Annotation{namespace: namespace, entity_type: entity_type}
        Annotation.changeset(annotation, attrs)
      end)

    if Enum.all?(changesets, & &1.valid?) do
      # In case of duplicate entities in the batch we'll only use the last entry.
      annotations =
        changesets
        |> Enum.map(&apply_changes/1)
        |> Enum.reverse()
        |> Enum.uniq_by(& &1.entity_id)
        |> Enum.reverse()

      {:ok, annotations}
    else
      {:error, :invalid_entries}
    end
  end

  defp cast_entries(_namespace, _entity_type, _entries), do: {:error, :invalid_entries}

  defp check_total(entries) do
    new = Enum.count(entries, &(&1.data != nil))

    if Repo.aggregate(Annotation, :count) + new > @max_annotations,
      do: {:error, :too_many_annotations},
      else: :ok
  end

  defp store(namespace, entity_type, entries) do
    existing_ids = existing_ids(entity_type, Enum.map(entries, & &1.entity_id))
    {entries, skipped} = Enum.split_with(entries, &MapSet.member?(existing_ids, &1.entity_id))
    {removed, written} = Enum.split_with(entries, &is_nil(&1.data))
    now = DateTime.utc_now(:second)

    rows =
      for %{entity_id: entity_id, data: data} <- written do
        %{
          namespace: namespace,
          entity_type: entity_type,
          entity_id: entity_id,
          data: data,
          inserted_at: now,
          updated_at: now
        }
      end

    Repo.insert_all(Annotation, rows,
      on_conflict: {:replace, [:data, :updated_at]},
      conflict_target: [:namespace, :entity_type, :entity_id]
    )

    removed_ids = Enum.map(removed, & &1.entity_id)

    from(a in Annotation,
      where:
        a.namespace == ^namespace and a.entity_type == ^entity_type and
          a.entity_id in ^removed_ids
    )
    |> Repo.delete_all()

    {:ok, %{skipped: skipped |> Enum.map(& &1.entity_id) |> Enum.uniq()}}
  end

  defp existing_ids(entity_type, ids) do
    from(e in Annotation.entity_schema(entity_type), where: e.id in ^ids, select: e.id)
    |> Repo.all()
    |> MapSet.new()
  end

  @doc """
  Removes orphaned annotations of entities that no longer exist. Because they
  are not linked using foreign keys we'll need to do this manually.
  """
  @spec remove_orphaned() :: non_neg_integer()
  def remove_orphaned do
    Annotation.entity_types()
    |> Enum.map(fn entity_type ->
      existing_ids = from(e in Annotation.entity_schema(entity_type), select: e.id)

      {count, _} =
        from(a in Annotation,
          where: a.entity_type == ^entity_type and a.entity_id not in subquery(existing_ids)
        )
        |> Repo.delete_all()

      count
    end)
    |> Enum.sum()
  end
end
