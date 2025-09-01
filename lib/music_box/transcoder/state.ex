defmodule MusicBox.Transcoder.State do
  defstruct jobs: %{},
            requests: %{},
            cleanup_timer: nil
end
