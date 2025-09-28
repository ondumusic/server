defmodule MusicBox.FileScanner.Entry do
  @moduledoc false

  defstruct [:path, :is_dir, scan_type: :quick]
end
