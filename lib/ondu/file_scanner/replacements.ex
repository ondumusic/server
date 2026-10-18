defmodule Ondu.FileScanner.Replacements do
  @moduledoc """
  The Replacements module is responsible to try and match files to determine
  whether or not it is a replacement or new file. For example when the file
  has been modified to fix a typo in one of its tags or it was replaced with
  a better audio version. We try to handle these separately to try and preserve
  the play history, any playlist entries, etc.
  """

  alias __MODULE__.Candidate
  alias Ondu.Files.File
  alias Ondu.FileScanner.{Analyzer, Utils}
  alias Ondu.Tracks.Track

  # We'll accept a duration difference tolerance of 1 second,
  # anything over will not count as a match.
  @max_duration_difference 1.0

  @doc """
  This matches missing files with new files that look like a replacement,
  meaning it was most likely retagged or reencoded.

  When a file matches more than one other file we can't be sure which one it is,
  so we'll ignore it in that case.

  It returns a list of tuples with the missing and their new candidate.
  """
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

  @doc """
  Returns the replacement candidate for a newly found file,
  or of a known file with its track preloaded.
  """
  @spec to_candidate(Analyzer.Result.t() | File.t()) :: Candidate.t()
  def to_candidate(%Analyzer.Result{path: path, metadata: metadata}) do
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

  def to_candidate(%File{track: %Track{} = track, metadata: metadata} = file) do
    %Candidate{
      file_id: file.id,
      path: file.path,
      duration: track.duration,
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
