defmodule MusicBox.FileScanner.Utils do
  def music_file?(path) do
    path
    |> Path.extname()
    |> String.downcase()
    |> case do
      ".mp3" -> true
      ".m4a" -> true
      ".aac" -> true
      ".flac" -> true
      ".ogg" -> true
      ".wav" -> true
      _ -> false
    end
  end
end
