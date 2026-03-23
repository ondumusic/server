defmodule MusicBox.Utils do
  @moduledoc false

  @spec valid_extname?(path :: String.t()) :: boolean()
  @valid_extensions ~w(
    .aac
    .aiff
    .flac
    .m4a
    .mp3
    .ogg
    .opus
    .wav
    .webm
  )
  def valid_extname?(path) do
    ext =
      path
      |> Path.extname()
      |> String.downcase()

    ext in @valid_extensions
  end
end
