defmodule MusicBox.Tool.ResizeArtwork do
  @moduledoc false
  @behaviour MusicBox.Tool

  require Logger

  @impl true
  def exec(opts) when is_list(opts), do: exec(Map.new(opts))

  def exec(%{album: album, path: path}) do
    Logger.debug("Resizing artwork for album #{album.id}, file: #{path}")

    ffmpeg_path = System.find_executable("ffmpeg") || throw(:ffmpeg_not_found)
    tmp_path = Path.rootname(path) <> ".tmp" <> Path.extname(path)
    args = ffmpeg_args(path, tmp_path)

    with true <- File.exists?(path),
         {_stdout, 0} <- System.cmd(ffmpeg_path, args, stderr_to_stdout: true),
         :ok <- File.rm(path),
         :ok <- File.rename(tmp_path, path) do
      :ok
    else
      false ->
        Logger.error("Failed to resize artwork for album #{album.id}, file not found?")
        {:error, :file_not_found}

      {_stdout, exitcode} ->
        Logger.error("Failed to resize artwork for album #{album.id}, exit code #{exitcode}")
        {:error, :failed_to_resize}
    end
  end

  defp ffmpeg_args(path, tmp_path) do
    [
      "-y",
      "-i",
      path,
      "-vf",
      "scale=500:500:force_original_aspect_ratio=decrease:flags=lanczos",
      "-q:v",
      "2",
      "-update",
      "1",
      tmp_path
    ]
  end
end
