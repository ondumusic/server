defmodule MusicBox.FileScanner.State do
  @moduledoc false

  defstruct demand: 0, entries: [], poll_timer: nil
end
