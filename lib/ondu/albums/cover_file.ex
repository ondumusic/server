defmodule Ondu.Albums.CoverFile do
  @moduledoc """
  A cover file (e.g. cover.jpg) found in the same directory as the album track files.

    * `path`: relative to the music path
    * `size`: in bytes
    * `last_modified_at`: the mtime of the file
  """

  use Ondu.Schema

  alias Ondu.Storage
  alias Ondu.Utils

  @type t :: %__MODULE__{}

  @primary_key false
  embedded_schema do
    field :path, :string
    field :size, :integer
    field :last_modified_at, :utc_datetime
  end

  @doc """
  Finds the cover file in the given file entries, or nil when there is
  none. When there is more than one the preferred one is returned, see
  `Ondu.Utils.cover_file_priority/1`.
  """
  @spec find([Storage.file_entry()]) :: t() | nil
  def find(entries) do
    entries
    |> Enum.filter(&Utils.cover_file?(&1.path))
    |> Enum.min_by(&Utils.cover_file_priority(&1.path), fn -> nil end)
    |> case do
      nil ->
        nil

      entry ->
        %__MODULE__{
          path: entry.path,
          size: entry.size,
          last_modified_at: DateTime.truncate(entry.mtime, :second)
        }
    end
  end
end
