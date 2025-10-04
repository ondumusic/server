defmodule MusicBox.FileScanner.Utils do
  @moduledoc false

  alias MusicBox.FileScanner.FileTypes

  @spec slugify(String.t()) :: String.t()
  def slugify(input) do
    Slug.slugify(input, separator: "-", lowercase: true)
  end

  @spec calculate_checksum!(Path.t()) :: String.t()
  def calculate_checksum!(path) do
    File.stream!(path, 2048, [])
    |> Enum.reduce(:crypto.hash_init(:sha), &:crypto.hash_update(&2, &1))
    |> :crypto.hash_final()
    |> Base.encode16(case: :lower)
  end

  @spec ffprobe(String.t()) :: {:ok, map()} | {:error, :ffprobe_failed}
  def ffprobe(path) do
    ffprobe_path = System.find_executable("ffprobe") || throw(:ffprobe_not_found)
    args = ~w(-v quiet -print_format json -show_format -show_streams -i) ++ [path]

    with {stdout, 0} <- System.cmd(ffprobe_path, args),
         {:ok, json} <- JSON.decode(stdout) do
      {:ok, json}
    else
      _ -> {:error, :ffprobe_failed}
    end
  end

  @spec to_integer(String.t() | integer() | nil) :: integer() | nil
  def to_integer(nil), do: nil
  def to_integer(n) when is_integer(n), do: n

  def to_integer(input) when is_binary(input) do
    case Integer.parse(input) do
      {n, _rest} -> n
      _ -> nil
    end
  end

  @spec detect_file_type(String.t()) :: {:ok, atom()} | {:error, :unknown}
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

  @spec short_hex(String.t(), non_neg_integer()) :: String.t()
  def short_hex(input, len) do
    :crypto.hash(:md5, input)
    |> String.slice(0, len)
    |> Base.encode16(case: :lower)
  end

  @spec random_hex(non_neg_integer()) :: String.t()
  def random_hex(len) do
    :crypto.strong_rand_bytes(len)
    |> Base.encode16(case: :lower)
  end
end
