defmodule Ondu.FileScanner.Plan do
  @moduledoc false

  alias Ondu.FileScanner.Analyzer

  @type move :: %{
          file_id: Ecto.UUID.t(),
          from: String.t(),
          to: String.t()
        }

  @type renamed_album :: %{
          album_id: Ecto.UUID.t(),
          album_artist: String.t(),
          album: String.t()
        }

  @type renamed_artist :: %{
          artist_id: Ecto.UUID.t(),
          artist: String.t()
        }

  @type t :: %__MODULE__{
          moved_files: [move()],
          replaced_files: [move()],
          renamed_albums: [renamed_album()],
          renamed_artists: [renamed_artist()],
          deleted_files: [Ecto.UUID.t()],
          saved_files: [Analyzer.Result.t()]
        }

  defstruct moved_files: [],
            replaced_files: [],
            renamed_albums: [],
            renamed_artists: [],
            deleted_files: [],
            saved_files: []
end
