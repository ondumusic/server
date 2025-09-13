defmodule MusicBox.Artwork.Fetcher.Embedded do
  use MusicBox.Artwork.Fetcher

  alias MusicBox.Files.File
  alias MusicBox.Repo

  def find(album) do
    album = Repo.preload(album, tracks: [:file])

    album.tracks
    |> Enum.reduce_while(nil, fn track, result ->
      case extract_artwork(track.file) do
        nil -> {:cont, result}
        bytes -> {:halt, bytes}
      end
    end)
    |> case do
      nil -> {:error, :not_found}
      bytes -> save_artwork(album, bytes)
    end
  end

  defp extract_artwork(%File{} = file) do
    ffmpeg_path = System.find_executable("ffmpeg") || throw(:ffmpeg_not_found)
    args = ffmpeg_args(file)

    case System.cmd(ffmpeg_path, args) do
      {stdout, 0} -> stdout
      _ -> nil
    end
  end

  defp ffmpeg_args(%File{} = file) do
    ["-i", file.path] ++ ~w(
      -map 0:v -map -0:V
      -vcodec copy
      -f image2pipe
      -v quiet -nostats
      pipe:1
    )
  end
end
