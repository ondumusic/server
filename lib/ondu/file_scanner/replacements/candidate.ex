defmodule Ondu.FileScanner.Replacements.Candidate do
  @moduledoc false

  # We use these fields for our matching logic to compare missing entries
  # with newly discovered entries.
  @type t :: %__MODULE__{
          file_id: Ecto.UUID.t() | nil,
          path: String.t(),
          duration: float() | nil,
          artist: String.t() | nil,
          album: String.t() | nil,
          title: String.t() | nil,
          disc: integer() | nil,
          track: integer() | nil
        }

  defstruct [:file_id, :path, :duration, :artist, :album, :title, :disc, :track]
end
