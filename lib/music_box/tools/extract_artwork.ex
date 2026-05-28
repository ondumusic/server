defmodule MusicBox.Tool.ExtractArtwork do
  @moduledoc false
  @behaviour MusicBox.Tool

  @impl true
  def exec(path) do
    ffmpeg_path = System.find_executable("ffmpeg") || throw(:ffmpeg_not_found)
    args = ffmpeg_args(path)

    case System.cmd(ffmpeg_path, args) do
      {stdout, 0} when byte_size(stdout) > 64 -> stdout
      _ -> {:error, :not_found}
    end
  end

  defp ffmpeg_args(path) do
    ["-i", path] ++ ~w(
      -map 0:v -map -0:V
      -vcodec copy
      -f image2pipe
      -v quiet -nostats
      pipe:1
    )
  end
end
