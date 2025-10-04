defmodule MusicBox.FileScanner do
  @moduledoc false

  alias MusicBox.FileScanner.Pipeline
  alias MusicBox.Settings

  @type scan_type :: :full | :quick
  @type scan_error :: :missing_music_path | :no_producer_found
  @spec scan(scan_type() | nil) :: {:ok, :scan_started} | {:error, scan_error()}
  def scan(scan_type \\ nil) do
    settings = Settings.get()

    if settings.music_path do
      Pipeline
      |> Broadway.producer_names()
      |> Enum.random()
      |> start_scanner(scan_type)
    else
      {:error, :missing_music_path}
    end
  end

  defp start_scanner(nil, _scan_type), do: {:error, :no_producer_found}

  defp start_scanner(producer, scan_type) do
    if producer_available?(producer) do
      send(producer, {:start_scan, type: scan_type})
      {:ok, :scan_started}
    else
      {:error, :no_producer_found}
    end
  end

  defp producer_available?(producer) do
    case Process.whereis(producer) do
      pid when not is_nil(pid) -> Process.alive?(pid)
      _ -> false
    end
  end
end
