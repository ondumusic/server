defmodule MusicBox.Tool.Cat do
  @moduledoc false
  @behaviour MusicBox.Tool

  @impl true
  def exec(path) do
    cat_bin = System.find_executable("cat")

    port =
      Port.open(
        {:spawn_executable, cat_bin},
        [
          :binary,
          :stream,
          :exit_status,
          :use_stdio,
          :stderr_to_stdout,
          args: [path]
        ]
      )

    {:ok, port}
  end
end
