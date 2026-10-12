defmodule Ondu.Transcoder.State do
  @moduledoc false

  alias Ondu.Transcoder.Config

  defstruct jobs: %{},
            config: %Config{},
            requests: %{},
            cleanup_timer: nil,
            queue: :queue.new()

  @type t :: %__MODULE__{}
end
