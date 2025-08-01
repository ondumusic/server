defmodule MusicBox.FileScanner.Utils do
  alias MusicBox.FileScanner.FileTypes

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

  def to_integer(nil), do: nil
  def to_integer(n) when is_integer(n), do: n

  def to_integer(input) when is_binary(input) do
    case Integer.parse(input) do
      {n, _rest} -> n
      _ -> nil
    end
  end

  def detect_file_type(path) do
    with {:ok, file} <- File.open(path, [:binary, :read]),
         header_bytes <- IO.binread(file, 262),
         _ <- File.close(file),
         {:ok, type} <- FileTypes.detect(header_bytes) do
      {:ok, type}
    else
      _ -> {:error, :unknown}
    end
  end
end
