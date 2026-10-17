defmodule Ondu.FileScanner.Deletions do
  @moduledoc false

  import Ecto.Query

  alias Ondu.Albums
  alias Ondu.Files.File
  alias Ondu.Repo
  alias Ondu.Storage
  alias Ondu.Tracks.Track

  require Logger

  @doc "Returns the ids of files that no longer exist in the music path."
  @spec find_missing_files(Keyword.t()) :: [Ecto.UUID.t()]
  def find_missing_files(opts \\ []), do: missing_file_ids(opts)

  # Checks a batch of files at a time, continuing after the last checked id.
  defp missing_file_ids(opts, last_id \\ nil) do
    batch_size = Keyword.get(opts, :batch_size, 500)

    case files_after(last_id, batch_size) do
      [] ->
        []

      files ->
        {last_id, _path} = List.last(files)
        missing = files |> Enum.chunk_every(50) |> Enum.flat_map(&verify_files/1)
        Enum.map(missing, &elem(&1, 0)) ++ missing_file_ids(opts, last_id)
    end
  end

  # NOTE: Repo.stream is useless with SQLite so let's do our own batching, by id
  # rather than offset so changes to the table can't make it skip files.
  defp files_after(last_id, limit) do
    query = from(f in File, select: {f.id, f.path}, order_by: f.id, limit: ^limit)
    query = if last_id, do: where(query, [f], f.id > ^last_id), else: query
    Repo.all(query)
  end

  @spec delete_files([Ecto.UUID.t()]) :: {:ok, non_neg_integer()}
  def delete_files(file_ids) do
    {deleted, errored} =
      file_ids
      |> Enum.chunk_every(50)
      |> Enum.reduce({0, 0}, &delete_files_reducer(&1, &2))

    if errored > 0, do: Logger.warning("failed to delete #{errored} files")

    # The results of deletions are not important, they are marked as deleted
    # through SQLite triggers.
    {:ok, deleted}
  end

  defp delete_files_reducer(file_ids, {deleted_acc, error_acc}) do
    # Get the album ids for any deleted files so we can invalidate their artwork
    album_ids =
      from(t in Track, where: t.file_id in ^file_ids, select: t.album_id)
      |> Repo.all()

    File
    |> where([f], f.id in ^file_ids)
    |> Repo.delete_all()
    |> case do
      {count, _} ->
        Albums.invalidate_artworks(album_ids)
        {deleted_acc + count, error_acc}

      _ ->
        {deleted_acc, error_acc + length(file_ids)}
    end
  end

  defp verify_files(files) do
    missing_files =
      files
      |> Enum.map(fn {_id, path} -> path end)
      |> Storage.find_missing_files()

    files
    |> Enum.flat_map(fn {id, path} ->
      if path in missing_files do
        [{id, path, :missing}]
      else
        []
      end
    end)
  end
end
