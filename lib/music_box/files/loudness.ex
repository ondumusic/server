defmodule MusicBox.Files.Loudness do
  @moduledoc """
  Loudness of a file as measured by the loudness worker.

    * `lufs`: integrated loudness in LUFS (ITU-R BS.1770)
    * `peak`: true peak in dBFS, `nil` for digital silence
    * `measured_at`: when we last attempted to measure
  """

  use MusicBox.Schema

  @type t :: %__MODULE__{}

  @primary_key false
  embedded_schema do
    field :lufs, :float
    field :peak, :float
    field :measured_at, :utc_datetime
  end
end
