defmodule MusicBox.Tool.Transcode do
  @moduledoc false
  @behaviour MusicBox.Tool

  @impl true
  def exec(args) do
    ffmpeg_bin = System.find_executable("ffmpeg")

    port =
      Port.open(
        {:spawn_executable, ffmpeg_bin},
        [
          :binary,
          :stream,
          :exit_status,
          :use_stdio,
          :stderr_to_stdout,
          args: ["-nostdin" | args]
        ]
      )

    {:ok, port}
  end
end
