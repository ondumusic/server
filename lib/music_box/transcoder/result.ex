defmodule MusicBox.Transcoder.Result do
  defstruct [:started_at, :completed_at, :failed_at, :chunk_count, :file_size]
end
