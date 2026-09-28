defmodule MusicBox.Albums.CoverFile do
  @moduledoc """
  A cover file (e.g. cover.jpg) found in the same directory as the album track files.

    * `path`: relative to the music path
    * `size`: in bytes
    * `last_modified_at`: the mtime of the file
  """

  use MusicBox.Schema

  @type t :: %__MODULE__{}

  @primary_key false
  embedded_schema do
    field :path, :string
    field :size, :integer
    field :last_modified_at, :utc_datetime
  end
end
