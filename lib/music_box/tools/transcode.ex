defmodule MusicBox.Tool.Transcode do
  @moduledoc false
  @behaviour MusicBox.Tool

  @impl true
  def exec(_args) do
    {:error, :not_implemented}
  end
end
