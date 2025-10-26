defmodule MusicBox.Tool do
  @moduledoc false
  @callback exec(args :: term()) :: {:ok, term()} | {:error, term()}

  def probe(path), do: impl(:probe_tool).exec(path)

  defp impl(tool) do
    Application.get_env(:music_box, tool)
  end
end
