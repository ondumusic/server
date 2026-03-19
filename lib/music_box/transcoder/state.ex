defmodule MusicBox.Transcoder.State do
  @moduledoc false

  alias MusicBox.Transcoder.Config

  defstruct jobs: %{},
            config: %Config{},
            requests: %{},
            cleanup_timer: nil,
            queue: :queue.new()

  @type t :: %__MODULE__{}
end
