defmodule MusicBox.Loudness do
  @moduledoc false

  alias MusicBox.Files.File
  alias MusicBox.Files.Loudness
  alias MusicBox.Repo
  alias MusicBox.Storage
  alias MusicBox.Tool

  import Ecto.Query

  require Logger

  @doc """
  Measures the loudness of a file and stores it.

  A failed measurement is stored too (without values) so we don't retry it until
  the file changes. The result is only stored if the file did not change while
  we were measuring, otherwise the scanner already reset it and we would store a
  measurement of the old file.
  """
  @spec measure(File.t()) :: {:ok, Loudness.t()} | {:error, :file_changed}
  def measure(%File{} = file) do
    measured_at = DateTime.utc_now(:second)

    loudness =
      case Tool.loudness(Storage.get_uri(file.path)) do
        {:ok, %{lufs: lufs, peak: peak}} ->
          %Loudness{lufs: lufs, peak: peak, measured_at: measured_at}

        {:error, reason} ->
          Logger.warning("failed to measure loudness of #{file.path}: #{inspect(reason)}")
          %Loudness{measured_at: measured_at}
      end

    case Repo.update_all(unchanged_file(file), set: [loudness: loudness]) do
      {1, _} -> {:ok, loudness}
      {0, _} -> {:error, :file_changed}
    end
  end

  defp unchanged_file(%File{id: id, size: size, last_modified_at: mtime}) do
    query = from(f in File, where: f.id == ^id and f.size == ^size)

    if is_nil(mtime),
      do: where(query, [f], is_nil(f.last_modified_at)),
      else: where(query, [f], f.last_modified_at == ^mtime)
  end
end
