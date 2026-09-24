defmodule MusicBox.Tool.Loudness do
  @moduledoc """
  Measures integrated loudness (LUFS) and true peak (dBFS) of the first audio
  stream using ffmpeg's `ebur128` filter (ITU-R BS.1770 / EBU R128).

  The filter only reports its results as a text summary on stderr, so we parse
  that. `loudnorm=print_format=json` would give JSON, but it is ~7x slower
  because it upsamples to 192kHz internally.

  A true peak of `-inf` (digital silence) is returned as `nil`.
  """
  @behaviour MusicBox.Tool

  @number ~S"(-?inf|-?\d+(?:\.\d+)?)"
  @integrated_regex Regex.compile!("Integrated loudness:\\s+I:\\s+#{@number} LUFS")
  @peak_regex Regex.compile!("True peak:\\s+Peak:\\s+#{@number} dBFS")

  @impl true
  def exec(path) do
    ffmpeg_path = System.find_executable("ffmpeg") || throw(:ffmpeg_not_found)

    case System.cmd(ffmpeg_path, ffmpeg_args(path), stderr_to_stdout: true) do
      {output, 0} -> parse(output)
      _ -> {:error, :measure_failed}
    end
  end

  @doc false
  def parse(output) do
    with [_, integrated] <- Regex.run(@integrated_regex, output),
         [_, peak] <- Regex.run(@peak_regex, output),
         integrated when is_float(integrated) <- to_float(integrated) do
      {:ok, %{lufs: integrated, peak: to_float(peak)}}
    else
      _ -> {:error, :measure_failed}
    end
  end

  defp to_float(value) do
    case Float.parse(value) do
      {float, ""} -> float
      _ -> nil
    end
  end

  defp ffmpeg_args(path) do
    ~w(-hide_banner -nostats -i) ++
      [path] ++
      ~w(
        -map 0:a:0
        -af ebur128=peak=true:framelog=quiet
        -f null -
      )
  end
end
