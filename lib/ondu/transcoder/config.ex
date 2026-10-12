defmodule Ondu.Transcoder.Config do
  @moduledoc false

  defstruct max_concurrency: 3,
            max_queue_size: 10

  @type t :: %__MODULE__{}
end
