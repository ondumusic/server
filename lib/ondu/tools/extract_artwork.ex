defmodule Ondu.Tool.ExtractArtwork do
  @moduledoc false
  @behaviour Ondu.Tool

  @timeout :timer.seconds(30)

  @impl true
  def exec(path) do
    ffmpeg_path = System.find_executable("ffmpeg") || throw(:ffmpeg_not_found)
    args = ffmpeg_args(path)

    case Ondu.Tool.cmd(ffmpeg_path, args, timeout: @timeout) do
      {stdout, 0} when byte_size(stdout) > 64 -> stdout
      _ -> {:error, :not_found}
    end
  end

  defp ffmpeg_args(path) do
    ["-nostdin", "-i", path] ++ ~w(
      -map 0:v -map -0:V
      -vcodec copy
      -f image2pipe
      -v quiet -nostats
      pipe:1
    )
  end
end
