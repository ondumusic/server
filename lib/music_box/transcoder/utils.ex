defmodule MusicBox.Transcoder.Utils do
  alias MusicBox.Files.File

  def bitrate_kbps, do: 256
  def chunk_size, do: 1024 * 1024

  def estimate_opus_size(%File{metadata: %{duration: duration}}) do
    audio_bytes = bitrate_kbps() * 1000 * duration / 8

    # Estimate the container and opus overhead (just add a %)
    webm_container_overhead = audio_bytes * 0.015
    opus_header_overhead = audio_bytes * 0.005

    # Return rounded number
    round(audio_bytes + webm_container_overhead + opus_header_overhead)
  end
end
