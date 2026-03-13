defmodule MusicBox.Tool do
  @moduledoc false
  @callback exec(args :: term()) :: {:ok, term()} | :ok | {:error, term()}

  def probe(path), do: impl(:probe_tool).exec(path)
  def transcode(args), do: impl(:transcode_tool).exec(args)
  def extract_artwork(path), do: impl(:extract_artwork_tool).exec(path)
  def resize_artwork(opts), do: impl(:resize_artwork_tool).exec(opts)

  defp impl(tool) do
    Application.get_env(:music_box, tool)
  end
end
