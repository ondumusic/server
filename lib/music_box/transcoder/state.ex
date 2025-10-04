defmodule MusicBox.Transcoder.State do
  @moduledoc false

  defstruct jobs: %{},
            requests: %{},
            cleanup_timer: nil

  @type t :: %__MODULE__{}
end
