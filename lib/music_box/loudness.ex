defmodule MusicBox.Loudness do
  @moduledoc false

  alias MusicBox.Files.File
  alias MusicBox.Files.Loudness
  alias MusicBox.Repo
  alias MusicBox.Storage
  alias MusicBox.Tool
  alias MusicBox.Tracks.Track

  import Ecto.Query

  require Logger

  @doc """
  Measures the loudness of a file and stores it.

  A failed measurement is stored too (without values) so we don't retry it until
  the file changes.
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

    Repo.transact(fn -> store(file, loudness) end)
  end

  defp store(file, loudness) do
    now = DateTime.utc_now(:second)

    case Repo.update_all(unchanged_file_query(file), set: [loudness: loudness, updated_at: now]) do
      {1, _} ->
        # If the values changed we need to update the Track.updated_at as well so
        # our syncing logic will inform clients to pick up the latest version.
        if is_float(loudness.lufs) and values_changed?(file.loudness, loudness),
          do: touch_tracks(file, now)

        {:ok, loudness}

      {0, _} ->
        {:error, :file_changed}
    end
  end

  defp values_changed?(%Loudness{lufs: lufs, peak: peak}, %Loudness{lufs: lufs, peak: peak}),
    do: false

  defp values_changed?(_old, _new), do: true

  defp touch_tracks(file, now) do
    from(t in Track, where: t.file_id == ^file.id)
    |> Repo.update_all(set: [updated_at: now])
  end

  defp unchanged_file_query(%File{id: id, size: size, last_modified_at: mtime}) do
    query = from(f in File, where: f.id == ^id and f.size == ^size)

    if is_nil(mtime),
      do: where(query, [f], is_nil(f.last_modified_at)),
      else: where(query, [f], f.last_modified_at == ^mtime)
  end
end
