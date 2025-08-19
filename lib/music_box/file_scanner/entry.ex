defmodule MusicBox.FileScanner.Entry do
  defstruct [:path, :is_dir, scan_type: :quick]
end
