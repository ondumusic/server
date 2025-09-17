defmodule MusicBox.FileScanner do
  alias MusicBox.FileScanner.Pipeline
  alias MusicBox.Settings

  def scan(scan_type \\ nil) do
    settings = Settings.get()

    if settings.music_path do
      Pipeline
      |> Broadway.producer_names()
      |> Enum.random()
      |> case do
        nil ->
          {:error, :no_producer_found}

        producer ->
          if producer_available?(producer) do
            send(producer, {:start_scan, type: scan_type})
            {:ok, :scan_started}
          else
            {:error, :no_producer_found}
          end
      end
    else
      {:error, :missing_music_path}
    end
  end

  defp producer_available?(producer) do
    with pid when not is_nil(pid) <- Process.whereis(producer) do
      Process.alive?(pid)
    else
      _ -> false
    end
  end
end
