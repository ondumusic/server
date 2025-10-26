defmodule MusicBox.Tool.ResizeArtwork do
  @moduledoc false
  @behaviour MusicBox.Tool

  require Logger

  @impl true
  def exec(opts) when is_list(opts), do: exec(Map.new(opts))

  def exec(%{album: album, path: path}) do
    vipsthumbnail = System.find_executable("vipsthumbnail") || throw(:vipsthumbnail_not_found)
    args = ~w(-t --size=500x500 --smartcrop attention) ++ ["--output=#{path}[Q=85]", path]

    Logger.debug("Resizing artwork for album #{album.id}, file: #{path}")

    with true <- File.exists?(path),
         {_stdout, 0} <- System.cmd(vipsthumbnail, args) do
      :ok
    else
      false ->
        Logger.error("Failed to resize artwork for album #{album.id}, file not found?")
        {:error, :file_not_found}

      {_stdout, exitcode} ->
        Logger.error("Failed to resize artwork for album #{album.id}, exit code #{exitcode}")
        {:error, :failed_to_resize}
    end
  end
end
