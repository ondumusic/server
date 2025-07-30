defmodule MusicBox.FileScanner.Utils do
  def calculate_checksum(path) do
    File.stream!(path, [], 2048)
    |> Enum.reduce(:crypto.hash_init(:sha), &:crypto.hash_update(&2, &1))
    |> :crypto.hash_final()
    |> Base.encode16(case: :lower)
  end

  def ffprobe(path) do
    ffprobe_path = System.find_executable("ffprobe") || throw(:ffprobe_not_found)
    args = ~w(-v quiet -print_format json -show_format -show_streams -i) ++ [path]

    with {stdout, 0} <- System.cmd(ffprobe_path, args),
         {:ok, json} <- Jason.decode(stdout) do
      {:ok, json}
    else
      _ -> %{error: :ffprobe_failed}
    end
  end

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

  def to_integer(nil), do: nil
  def to_integer(n) when is_integer(n), do: n

  def to_integer(input) when is_binary(input) do
    case Integer.parse(input) do
      {n, _rest} -> n
      _ -> nil
    end
  end
end
