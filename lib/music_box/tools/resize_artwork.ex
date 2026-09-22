defmodule MusicBox.Tool.ResizeArtwork do
  @moduledoc false
  @behaviour MusicBox.Tool

  alias MusicBox.Artwork.Fetcher
  require Logger

  @impl true
  def exec(opts) when is_list(opts), do: exec(Map.new(opts))

  def exec(%{album: album, path: path}) do
    Logger.debug("Resizing artwork for album #{album.id}, file: #{path}")

    ffmpeg_path = System.find_executable("ffmpeg") || throw(:ffmpeg_not_found)
    tmp_path = Fetcher.tmp_path(path)
    args = ffmpeg_args(path, tmp_path)

    with true <- File.exists?(path),
         {_stdout, 0} <- System.cmd(ffmpeg_path, args, stderr_to_stdout: true),
         :ok <- File.rename(tmp_path, path) do
      :ok
    else
      false ->
        Logger.error("Failed to resize artwork for album #{album.id}, file not found?")
        {:error, :file_not_found}

      {:error, reason} ->
        File.rm(tmp_path)
        Logger.error("Failed to resize artwork for album #{album.id} (reason: #{reason})")
        {:error, :failed_to_resize}

      {_stdout, exitcode} ->
        File.rm(tmp_path)
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
      "scale='min(min(iw,ih),500)':'min(min(iw,ih),500)':flags=lanczos",
      "-q:v",
      "2",
      "-update",
      "1",
      tmp_path
    ]
  end
end
