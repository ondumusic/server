defmodule Ondu.Artwork do
  @moduledoc """
  This module deals with different kinds of artwork (e.g. albums) and their
  resizing and storing. Every kind can have their own config.
  """

  alias Ondu.Albums
  alias Ondu.Albums.Album
  alias Ondu.Artists
  alias Ondu.Artists.Artist
  alias Ondu.Repo
  alias Ondu.Tool

  import Ecto.Query

  @type kind :: :albums | :artists
  @type variant :: :thumbnail | :large

  # The artwork schema of each kind has a changeset/2, updating artwork keeps the
  # fields in `keep` (e.g. set by others). Originals are only kept when they can't
  # be found again, like uploads (album artwork is found in the music files).
  @kinds %{
    albums: %{
      parent: Album,
      artwork: Albums.Artwork,
      fit: :square,
      keep: [:invalidated_at],
      keep_original: false
    },
    artists: %{
      parent: Artist,
      artwork: Artists.Artwork,
      fit: :shortest_side,
      keep: [:inserted_at],
      keep_original: true
    }
  }

  # Maximum size (in pixels) of each variant, artwork is never upscaled.
  @variants [thumbnail: 128, large: 640]
  @variant_names Keyword.keys(@variants)

  # Restrict the maximum file size because the bigger the file the more memory
  # it will use to resize images, and realistically we don't expect such large
  # images under normal use.
  @max_size 25 * 1024 * 1024

  defp kind!(kind), do: Map.fetch!(@kinds, kind)

  @spec variants() :: [{variant(), pos_integer()}]
  def variants, do: @variants

  @spec max_size() :: pos_integer()
  def max_size, do: @max_size

  @spec dir(kind(), String.t()) :: String.t()
  def dir(kind, id) when is_map_key(@kinds, kind),
    do: Path.join([Ondu.Config.artwork_path(), to_string(kind), id])

  @spec variant_path(kind(), String.t(), variant()) :: String.t()
  def variant_path(kind, id, variant) when variant in @variant_names,
    do: Path.join(dir(kind, id), "#{variant}.jpg")

  @spec original_path(kind(), String.t()) :: String.t()
  def original_path(kind, id), do: Path.join(dir(kind, id), "original")

  @doc """
  Returns the actual width and height of each variant.
  """
  @spec variant_sizes(kind(), %{
          :width => pos_integer(),
          :height => pos_integer(),
          optional(atom()) => any()
        }) ::
          [{variant(), pos_integer(), pos_integer()}]
  def variant_sizes(kind, %{width: width, height: height})
      when is_integer(width) and is_integer(height) do
    fit = kind!(kind).fit

    for {variant, size} <- @variants do
      {width, height} = variant_size(fit, width, height, size)
      {variant, width, height}
    end
  end

  # Fitted within the size and padded to a square.
  defp variant_size(:square, width, height, size) do
    size = min(max(width, height), size)
    {size, size}
  end

  # Keeps the aspect ratio, with the shortest side scaled to the size.
  defp variant_size(:shortest_side, width, height, size),
    do: Tool.ResizeArtwork.shortest_side_size(width, height, size)

  @doc """
  Stores the resized image at the given path as the artwork for the parent (e.g.
  an album), together with the given params. Resizing is skipped when the image
  did not change (hash is identical)
  """
  @spec put(kind(), struct(), String.t(), map()) ::
          Repo.result(struct()) | {:error, :too_large | :invalid_image | :failed_to_write}
  def put(kind, parent, path, params \\ %{}) do
    current = Repo.get(kind!(kind).artwork, parent.id)

    with :ok <- check_size(path),
         {:ok, hash} <- file_hash(path),
         {:ok, dimensions} <- resize(kind, parent, path, hash, current) do
      save(kind, parent, current, Map.merge(params, Map.put(dimensions, :hash, hash)))
    end
  end

  @doc """
  Saves the artwork for the parent, when it changed the parent is touched so
  clients sync it. Its variants are removed when it no longer has artwork.
  """
  @spec save(kind(), struct(), struct() | nil, map()) :: Repo.result(struct())
  def save(kind, parent, current, params) do
    with {:ok, artwork} <- Repo.transact(fn -> store(kind, parent, current, params) end) do
      if changed?(current, artwork), do: after_change(kind, parent, artwork)
      {:ok, artwork}
    end
  end

  @doc "Removes the artwork of the parent."
  @spec delete(kind(), struct()) :: :ok
  def delete(kind, parent) do
    schema = kind!(kind).artwork
    [key] = schema.__schema__(:primary_key)

    {count, _} = Repo.delete_all(from(a in schema, where: field(a, ^key) == ^parent.id))
    File.rm_rf(dir(kind, parent.id))

    if count > 0 do
      touch(kind, parent)
      broadcast(kind, parent)
    end

    :ok
  end

  @doc "Inserts or updates the artwork row of the parent."
  @spec upsert(kind(), struct(), map()) :: Repo.result(struct())
  def upsert(kind, parent, params) do
    %{artwork: schema, keep: keep} = kind!(kind)
    [key] = schema.__schema__(:primary_key)

    schema
    |> struct([{key, parent.id}])
    |> schema.changeset(params)
    |> Repo.insert(on_conflict: {:replace_all_except, [key | keep]}, conflict_target: key)
  end

  defp store(kind, parent, current, params) do
    with {:ok, artwork} <- upsert(kind, parent, params) do
      if changed?(current, artwork), do: touch(kind, parent)
      {:ok, artwork}
    end
  end

  defp check_size(path) do
    case File.stat(path) do
      {:ok, %{size: size}} when size > 0 and size <= @max_size -> :ok
      {:ok, %{size: 0}} -> {:error, :invalid_image}
      {:ok, _stat} -> {:error, :too_large}
      {:error, _reason} -> {:error, :invalid_image}
    end
  end

  defp resize(_kind, _parent, _path, hash, %{hash: hash, width: width, height: height}),
    do: {:ok, %{width: width, height: height}}

  defp resize(kind, parent, path, _hash, _current) do
    variants =
      for {variant, size} <- @variants, do: {variant_path(kind, parent.id, variant), size}

    opts = %{id: parent.id, path: path, variants: variants, fit: kind!(kind).fit}

    with {:ok, %{width: width, height: height}} <- resize_artwork(opts),
         :ok <- maybe_keep_original(kind, parent, path) do
      {:ok, %{width: width, height: height}}
    end
  end

  defp resize_artwork(opts) do
    case Tool.resize_artwork(opts) do
      {:ok, dimensions} -> {:ok, dimensions}
      {:error, :too_large} -> {:error, :too_large}
      {:error, _reason} -> {:error, :invalid_image}
    end
  end

  defp maybe_keep_original(kind, parent, path) do
    if kind!(kind).keep_original do
      original_path = original_path(kind, parent.id)
      tmp_path = tmp_path(original_path)

      with :ok <- File.cp(path, tmp_path),
           :ok <- File.rename(tmp_path, original_path) do
        :ok
      else
        _error ->
          File.rm(tmp_path)
          {:error, :failed_to_write}
      end
    else
      :ok
    end
  end

  defp changed?(%{hash: hash}, %{hash: hash}), do: false
  defp changed?(nil, %{hash: nil}), do: false
  defp changed?(_old_artwork, _new_artwork), do: true

  # We'll bump the parent its updated_at so it will be updated with the next
  # client sync and return with the new artwork.
  defp touch(kind, parent) do
    from(p in kind!(kind).parent, where: p.id == ^parent.id)
    |> Repo.update_all(set: [updated_at: DateTime.utc_now()])
  end

  defp after_change(kind, parent, artwork) do
    if is_nil(artwork.hash), do: File.rm_rf(dir(kind, parent.id))
    broadcast(kind, parent)
  end

  defp broadcast(kind, parent) do
    OnduWeb.Endpoint.broadcast!("library:sync", "processed", %{kind => [parent.id]})
  end

  @doc "A short hash of a file, used in artwork urls."
  @spec file_hash(String.t()) :: {:ok, String.t()} | {:error, File.posix()}
  def file_hash(source_path) do
    with {:ok, bytes} <- File.read(source_path) do
      hash = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
      {:ok, binary_part(hash, 0, 16)}
    end
  end

  @spec tmp_path(String.t()) :: String.t()
  def tmp_path(path) do
    Path.rootname(path) <> ".#{System.unique_integer([:positive])}.tmp" <> Path.extname(path)
  end

  @doc """
  Removes the artwork of parents (e.g. albums) that no longer exist in the
  database.

  It will attempt to do this based on the directory names (UUID) because if we
  query the database for all known artwork it will not have the deleted entries
  anymore and the files stay orphaned.
  """
  @spec remove_orphaned() :: non_neg_integer()
  def remove_orphaned do
    @kinds
    |> Enum.map(fn {kind, %{parent: parent}} -> remove_orphaned(kind, parent) end)
    |> Enum.sum()
  end

  defp remove_orphaned(kind, parent) do
    ids =
      case File.ls(Path.join(Ondu.Config.artwork_path(), to_string(kind))) do
        {:ok, names} -> Enum.filter(names, &id?/1)
        {:error, _reason} -> []
      end

    existing =
      ids
      |> Enum.chunk_every(1000)
      |> Enum.flat_map(&Repo.all(from(p in parent, where: p.id in ^&1, select: p.id)))
      |> MapSet.new()

    orphaned = Enum.reject(ids, &MapSet.member?(existing, &1))
    Enum.each(orphaned, &File.rm_rf(dir(kind, &1)))
    length(orphaned)
  end

  # Only folders named exactly like an id (uuid).
  # NOTE that cast always returns lowercase, but our server also only creates
  # lowercase uuid folders so other casing should be ignored.
  defp id?(name), do: Ecto.UUID.cast(name) == {:ok, name}
end
