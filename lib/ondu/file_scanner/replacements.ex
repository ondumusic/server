defmodule Ondu.FileScanner.Replacements do
  @moduledoc """
  The Replacements module is responsible to try and match files to determine
  whether or not it is a replacement or new file. For example when the file
  has been modified to fix a typo in one of its tags or it was replaced with
  a better audio version. We try to handle these separately to try and preserve
  the play history, any playlist entries, etc.
  """

  import Ecto.Query

  alias __MODULE__.Candidate
  alias Ondu.Files.File
  alias Ondu.FileScanner.{Analyzer, Utils}
  alias Ondu.Repo
  alias Ondu.Tracks.Track

  require Logger

  # We'll accept a duration difference tolerance of 1 second,
  # anything over will not count as a match.
  @max_duration_difference 1.0

  # Compares missing files with any newly found files to determine whether or
  # not this file has a possible candidate to replace the missing track. This
  # is a process that happens after all batches have been inserted, so we
  # collect the possible replacement to process later.
  @spec find_possible_replacements(
          Ecto.Repo.t(),
          [Analyzer.Result.t()],
          MapSet.t(Ecto.UUID.t()),
          map()
        ) ::
          {:ok, [Analyzer.Result.t()]}
  def find_possible_replacements(repo, files, missing_file_ids, %{moved_files: moved_file_ids}) do
    missing_file_ids = MapSet.difference(missing_file_ids, MapSet.new(moved_file_ids))

    # No missing files? Then we have nothing to do.
    if MapSet.size(missing_file_ids) == 0 do
      {:ok, []}
    else
      file_paths = Enum.map(files, & &1.path)

      known_paths =
        from(f in File, where: f.path in ^file_paths, select: f.path)
        |> repo.all()
        |> MapSet.new()

      new_files = Enum.reject(files, &MapSet.member?(known_paths, &1.path))
      new_candidates = Enum.map(new_files, &to_candidate/1)
      missing = find_missing_candidates(repo, new_candidates, missing_file_ids)

      possible_replacements =
        Enum.filter(new_files, fn file ->
          Enum.any?(missing, &replaced?(&1, to_candidate(file)))
        end)

      {:ok, possible_replacements}
    end
  end

  @doc """
  This will match possible replacements with missing files. For any eligible
  replacements it will replace the path of the file entry in the database
  instead of creating new ones.

  Returns the ids of the replaced files.
  """
  @spec replace_files([Analyzer.Result.t()], MapSet.t(Ecto.UUID.t())) :: {:ok, [Ecto.UUID.t()]}
  def replace_files([], _missing_file_ids), do: {:ok, []}

  def replace_files(files, missing_file_ids) do
    new = Enum.map(files, &to_candidate/1)
    missing = find_missing_candidates(Repo, new, missing_file_ids)
    replaced = match(missing, new)

    for {old, new} <- replaced do
      from(f in File, where: f.id == ^old.file_id)
      |> Repo.update_all(set: [path: new.path])

      Logger.info("Replaced #{old.path} with #{new.path}")
    end

    {:ok, Enum.map(replaced, fn {old, _new} -> old.file_id end)}
  end

  @spec match([Candidate.t()], [Candidate.t()]) :: [{Candidate.t(), Candidate.t()}]
  def match(missing, new) do
    Enum.flat_map(missing, fn old ->
      with [file] <- Enum.filter(new, &replaced?(old, &1)),
           [^old] <- Enum.filter(missing, &replaced?(&1, file)) do
        [{old, file}]
      else
        _none_or_multiple -> []
      end
    end)
  end

  @spec replaced?(Candidate.t(), Candidate.t()) :: boolean()
  def replaced?(old, new), do: retagged?(old, new) or reencoded?(old, new)

  @spec retagged?(Candidate.t(), Candidate.t()) :: boolean()
  def retagged?(%Candidate{} = old, %Candidate{} = new) do
    same_audio? = is_float(old.duration) and old.duration == new.duration
    same_audio? and (same?(old.title, new.title) or same?(old.album, new.album))
  end

  @spec reencoded?(Candidate.t(), Candidate.t()) :: boolean()
  def reencoded?(%Candidate{} = old, %Candidate{} = new) do
    similar_audio? = similar_duration?(old.duration, new.duration)

    same_tags? =
      same?(old.artist, new.artist) and
        same?(old.album, new.album) and
        same?(old.title, new.title)

    same_position? = old.disc == new.disc and old.track == new.track

    # Finally return the result of this reencoded check
    similar_audio? and same_tags? and same_position?
  end

  # Attempt to load existing Track records from the missing files based on
  # the duration (with margin). This might look weird but don't worry this
  # is just to select likely candidates, the actual comparison happens later.
  defp find_missing_candidates(repo, candidates, missing_file_ids) do
    durations = candidates |> Enum.map(& &1.duration) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    # Build a dynamic lookup based on all the file durations
    similar_duration =
      Enum.reduce(durations, dynamic(false), fn duration, conditions ->
        min = duration - @max_duration_difference
        max = duration + @max_duration_difference
        dynamic([t], ^conditions or (t.duration >= ^min and t.duration <= ^max))
      end)

    from(t in Track,
      join: f in assoc(t, :file),
      where: ^similar_duration,
      select: %{
        file_id: f.id,
        path: f.path,
        duration: t.duration,
        artist: f.metadata["artist"],
        album: f.metadata["album"],
        title: f.metadata["title"],
        disc: f.metadata["disc"],
        track: f.metadata["track"]
      }
    )
    |> repo.all()
    |> Enum.filter(&MapSet.member?(missing_file_ids, &1.file_id))
    |> Enum.map(&struct!(Candidate, &1))
  end

  defp to_candidate(%Analyzer.Result{path: path, metadata: metadata}) do
    %Candidate{
      path: path,
      duration: metadata.duration,
      artist: metadata.artist,
      album: metadata.album,
      title: metadata.title,
      disc: metadata.disc,
      track: metadata.track
    }
  end

  defp similar_duration?(old, new) when is_float(old) and is_float(new),
    do: abs(old - new) <= @max_duration_difference

  defp similar_duration?(_old, _new), do: false

  # Tags are compared by their slug (which is kind of a normalised version),
  # so fixes in capitalization, punctuation or accents (e.g. "Dont stop me now"
  # to "Don't Stop Me Now") should appear the same.
  defp same?(old, new) when is_binary(old) and is_binary(new) do
    slug = Utils.slugify(old)
    slug != nil and slug == Utils.slugify(new)
  end

  defp same?(_old, _new), do: false
end
