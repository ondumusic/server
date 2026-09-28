defmodule MusicBox.Loudness do
  @moduledoc false

  alias MusicBox.Albums.Album
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

  @doc """
  Approximates the loudness of an album from its (preloaded) tracks, so clients
  can use one gain for all tracks when the album is played in sequence.

  The loudness is the energy average of the tracks weighted by their duration,
  it differs slightly from measuring all audio at once as every track is gated
  separately. The peak is the highest peak of the tracks. Returns nil until all
  tracks are measured.
  """
  @spec album_loudness([Track.t()]) :: %{lufs: float(), peak: float() | nil} | nil
  def album_loudness(tracks) do
    measured =
      for %Track{duration: duration, file: %File{loudness: %Loudness{lufs: lufs} = loudness}} <-
            tracks,
          is_float(lufs),
          do: {duration || 0.0, loudness}

    total_duration = Enum.sum_by(measured, fn {duration, _loudness} -> duration end)

    if measured != [] and length(measured) == length(tracks) and total_duration > 0 do
      energy =
        Enum.sum_by(measured, fn {duration, loudness} ->
          duration * :math.pow(10, loudness.lufs / 10)
        end)

      peaks = for {_duration, %{peak: peak}} <- measured, is_float(peak), do: peak

      %{
        lufs: Float.round(10 * :math.log10(energy / total_duration), 2),
        peak: Enum.max(peaks, fn -> nil end)
      }
    end
  end

  defp store(file, loudness) do
    now = DateTime.utc_now(:second)

    case Repo.update_all(unchanged_file_query(file), set: [loudness: loudness, updated_at: now]) do
      {1, _} ->
        # If the values changed we need to update the Track.updated_at (and the
        # Album.updated_at for its loudness) as well so our syncing logic will
        # inform clients to pick up the latest version.
        if is_float(loudness.lufs) and values_changed?(file.loudness, loudness),
          do: touch_tracks_and_albums(file, now)

        {:ok, loudness}

      {0, _} ->
        {:error, :file_changed}
    end
  end

  defp values_changed?(%Loudness{lufs: lufs, peak: peak}, %Loudness{lufs: lufs, peak: peak}),
    do: false

  defp values_changed?(_old, _new), do: true

  defp touch_tracks_and_albums(file, now) do
    from(t in Track, where: t.file_id == ^file.id)
    |> Repo.update_all(set: [updated_at: now])

    album_ids = from(t in Track, where: t.file_id == ^file.id, select: t.album_id)

    from(al in Album, where: al.id in subquery(album_ids))
    |> Repo.update_all(set: [updated_at: now])
  end

  defp unchanged_file_query(%File{id: id, size: size, last_modified_at: mtime}) do
    query = from(f in File, where: f.id == ^id and f.size == ^size)

    if is_nil(mtime),
      do: where(query, [f], is_nil(f.last_modified_at)),
      else: where(query, [f], f.last_modified_at == ^mtime)
  end
end
