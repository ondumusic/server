defmodule MusicBox.FileScanner.State do
  defstruct demand: 0, entries: [], poll_timer: nil
end
