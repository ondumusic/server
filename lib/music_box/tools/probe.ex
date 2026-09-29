defmodule MusicBox.Tool.Probe do
  @moduledoc false
  @behaviour MusicBox.Tool

  @timeout :timer.seconds(5)

  @impl true
  def exec(path) do
    ffprobe_path = System.find_executable("ffprobe") || throw(:ffprobe_not_found)
    args = ~w(-v quiet -print_format json -show_format -show_streams -i) ++ [path]

    with {stdout, 0} <- MusicBox.Tool.cmd(ffprobe_path, args, timeout: @timeout),
         {:ok, json} <- JSON.decode(stdout) do
      {:ok, json}
    else
      _ -> {:error, :probe_failed}
    end
  end
end
