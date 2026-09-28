defmodule MusicBox.Utils do
  @moduledoc false

  @spec valid_extname?(path :: String.t()) :: boolean()
  @valid_extensions ~w(
    .aac
    .aiff
    .flac
    .m4a
    .mp3
    .ogg
    .opus
    .wav
    .webm
  )
  def valid_extname?(path) do
    ext = path |> Path.extname() |> String.downcase()

    ext in @valid_extensions
  end

  # Cover files inside same directory as the tracks of an album (e.g. cover.jpg)
  # in order of preference when a folder has more than one.
  @cover_names ~w(cover front folder album albumart)
  @cover_extensions ~w(.jpg .jpeg .png .webp)

  @spec cover_file?(path :: String.t()) :: boolean()
  def cover_file?(path), do: cover_file_priority(path) != nil

  @doc """
  Returns a sortable priority for cover files (lower is better), or nil when the
  path is not a cover file.
  """
  @spec cover_file_priority(path :: String.t()) :: {non_neg_integer(), non_neg_integer()} | nil
  def cover_file_priority(path) do
    ext = path |> Path.extname() |> String.downcase()
    name = path |> Path.basename() |> Path.rootname() |> String.downcase()

    with name_index when is_integer(name_index) <- Enum.find_index(@cover_names, &(&1 == name)),
         ext_index when is_integer(ext_index) <- Enum.find_index(@cover_extensions, &(&1 == ext)) do
      {name_index, ext_index}
    end
  end
end
