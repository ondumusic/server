defmodule Ondu.FileScanner.Utils do
  @moduledoc false

  alias Ondu.FileScanner.FileTypes

  @spec slugify(String.t()) :: String.t() | nil
  def slugify(input) do
    Slug.slugify(
      input,
      separator: "-",
      lowercase: true,
      ignore: ["(", ")"]
    )
  end

  @type sort_name_opts :: {:strip_prefixes, [String.t()]}
  @spec sort_name(String.t(), [sort_name_opts()]) :: String.t()
  def sort_name(input, opts \\ []) do
    normalised =
      Slug.slugify(
        input,
        lowercase: true,
        separator: " ",
        ignore: ["(", ")"]
      )

    Keyword.get(opts, :strip_prefixes, [])
    |> Enum.map(&String.downcase/1)
    |> Enum.reduce_while(normalised, fn prefix, result ->
      if String.starts_with?(result, prefix <> " ") do
        prefix_size = String.length(prefix)
        result = String.slice(result, prefix_size..-1//1) |> String.trim()
        {:halt, result}
      else
        {:cont, result}
      end
    end)
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

  @spec detect_file_type(String.t()) :: {:ok, FileTypes.t()} | {:error, :unknown}
  def detect_file_type(path) do
    with header_bytes <- Ondu.Storage.get_bytes(path, 0, 262),
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
