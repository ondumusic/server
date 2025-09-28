defmodule MusicBox.Transcoder.Result do
  @moduledoc false

  defstruct [:started_at, :completed_at, :failed_at, :chunk_count, :file_size, persisted: false]
end
