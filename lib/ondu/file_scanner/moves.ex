defmodule Ondu.FileScanner.Moves do
  @moduledoc false

  import Ecto.Query

  alias Ondu.Albums
  alias Ondu.Files.{File, FileMetadata}
  alias Ondu.FileScanner.Analyzer
  alias Ondu.Tracks.Track

  require Logger

  # A new path with the same size and tags as a missing file is that file moved
  # (or renamed), its path is updated so it keeps its id and with it everything
  # linked to its track (plays, playlist items, ...). Several new paths for the
  # same tags and size are copies of the same file, so they are paired with the
  # missing files in any order. Returns the ids of the moved files.
  @spec move_files(Ecto.Repo.t(), [Analyzer.Result.t()], MapSet.t(Ecto.UUID.t()), map()) ::
          {:ok, [Ecto.UUID.t()]}
  def move_files(repo, files, missing_file_ids, _results) do
    paths = Enum.map(files, & &1.path)

    # Gets all known paths from the database
    known_paths =
      from(f in File, where: f.path in ^paths, select: f.path)
      |> repo.all()
      |> MapSet.new()

    # Reject any `files` that are already known.
    new_files = Enum.reject(files, &MapSet.member?(known_paths, &1.path))

    # Then create a list of unique sizes which will be one of the ways we'll
    # try to detect moved files.
    sizes = new_files |> Enum.map(& &1.size) |> Enum.uniq()

    # Now we will query any files based on identical file size,
    # and only keep the ones that match the `missing_file_ids`.
    missing_files =
      from(f in File, where: f.size in ^sizes)
      |> repo.all()
      |> Enum.filter(&MapSet.member?(missing_file_ids, &1.id))

    # Any matches will be considered a move and updated immediately,
    # and touch moved tracks to indicate they have been updated.
    moved = match(missing_files, new_files)

    # When we update the file `path` on the existing record to the new path the
    # rest of the scanning pipeline will see it as an unchanged file instead of
    # a new file.
    for {missing_file, file} <- moved do
      from(f in File, where: f.id == ^missing_file.id)
      |> repo.update_all(set: [path: file.path, last_modified_at: file.last_modified_at])

      Logger.info("Moved #{missing_file.path} to #{file.path}")
    end

    file_ids = Enum.map(moved, fn {missing_file, _file} -> missing_file.id end)

    # Bump the updated_at so sync will expose the updated relativeFilePath, and
    # also mark the artwork as invalidated so it will refresh this too if needed.
    touch_moved_tracks(repo, file_ids)
    {:ok, file_ids}
  end

  @doc """
  This matches known missing files with new files that have the same size
  and metadata, meaning it is most likely a moved file. It returns a list
  of tuples with the missing_file and the newly found file.
  """
  @spec match([File.t()], [Analyzer.Result.t()]) :: [{File.t(), Analyzer.Result.t()}]
  def match(missing_files, new_files) do
    missing_files =
      missing_files
      |> Enum.sort_by(& &1.path)
      |> Enum.group_by(&{&1.size, comparable_metadata(&1.metadata)})

    new_files
    |> Enum.sort_by(& &1.path)
    |> Enum.group_by(&{&1.size, comparable_metadata(&1.metadata)})
    |> Enum.flat_map(fn {key, files} -> Enum.zip(Map.get(missing_files, key, []), files) end)
  end

  defp comparable_metadata(metadata) do
    %FileMetadata{}
    |> FileMetadata.changeset(Map.from_struct(metadata))
    |> Ecto.Changeset.apply_changes()
  end

  # The path of their tracks changed, and their album directory might have.
  defp touch_moved_tracks(_repo, []), do: :ok

  defp touch_moved_tracks(repo, file_ids) do
    {_count, album_ids} =
      from(t in Track, where: t.file_id in ^file_ids, select: t.album_id)
      |> repo.update_all(set: [updated_at: DateTime.utc_now(:second)])

    Albums.invalidate_artworks(album_ids)
  end
end
