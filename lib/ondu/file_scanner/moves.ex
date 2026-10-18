defmodule Ondu.FileScanner.Moves do
  @moduledoc false

  alias Ondu.Files.{File, FileMetadata}
  alias Ondu.FileScanner.Analyzer

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
end
