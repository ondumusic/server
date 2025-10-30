defmodule MusicBox.FileScanner.Walker do
  @moduledoc false
  require Logger

  @spec walk(path :: String.t()) :: Enumerable.t()
  def walk(path) do
    Stream.resource(
      fn -> [path] end,
      &next/1,
      fn _ -> :ok end
    )
  end

  defp next([]), do: {:halt, []}

  defp next([current | rest]) do
    cond do
      File.regular?(current) -> {[current], rest}
      File.dir?(current) -> list_dir(current, rest)
      true -> {[], rest}
    end
  end

  defp list_dir(current, rest) do
    case File.ls(current) do
      {:ok, []} ->
        {[], rest}

      {:ok, entries} ->
        new_paths = Enum.map(entries, &Path.join(current, &1))
        {[], new_paths ++ rest}

      {:error, reason} ->
        Logger.error("failed to read directory: #{current} (#{reason})")
        {[], rest}
    end
  end
end
