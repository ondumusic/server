defmodule MusicBox.Transcoder.CacheCleanup do
  @moduledoc """
  Removes cached transcodes that are no longer useful: of files that were
  deleted, of files that changed after they were transcoded and of presets that
  no longer exist. When the cache is still larger than the maximum size the
  oldest transcodes are removed as well.

  Transcodes completed in the last hour are always kept, they might still be
  streamed.
  """

  alias MusicBox.Files.File
  alias MusicBox.Repo
  alias MusicBox.Transcoder.{Cache, Preset}

  import Ecto.Query

  @min_age_seconds 3600

  @type opts :: [now: DateTime.t(), max_size: pos_integer() | nil]

  @spec run(opts()) :: {:ok, non_neg_integer()}
  def run(opts \\ []) do
    now = Keyword.get(opts, :now, DateTime.utc_now(:second))
    max_size = Keyword.get(opts, :max_size, MusicBox.Config.transcode_max_cache_size())
    cutoff = DateTime.add(now, -@min_age_seconds)

    {old, recent} = Enum.split_with(Cache.entries(), &DateTime.before?(&1.completed_at, cutoff))
    content_changed_at = content_changed_at(old)
    {unused, used} = Enum.split_with(old, &unused?(&1, content_changed_at))
    oldest = oldest_over_max_size(used, recent, max_size)

    Cache.delete_entries(unused ++ oldest)
    {:ok, length(unused) + length(oldest)}
  end

  defp unused?(entry, content_changed_at) do
    case Map.fetch(content_changed_at, entry.file_id) do
      # The file was deleted.
      :error ->
        true

      {:ok, changed_at} ->
        entry.preset_id not in preset_ids() or
          (changed_at != nil and DateTime.before?(entry.completed_at, changed_at))
    end
  end

  defp oldest_over_max_size(_entries, _recent, nil), do: []

  defp oldest_over_max_size(entries, recent, max_size) do
    size = Enum.sum_by(entries ++ recent, & &1.size)

    entries
    |> Enum.sort_by(& &1.completed_at, DateTime)
    |> Enum.reduce_while({[], size}, fn entry, {oldest, size} ->
      if size > max_size,
        do: {:cont, {[entry | oldest], size - entry.size}},
        else: {:halt, {oldest, size}}
    end)
    |> elem(0)
  end

  # Chunked as every id is a query parameter and SQLite limits how many a query
  # can have.
  defp content_changed_at(entries) do
    entries
    |> Enum.map(& &1.file_id)
    |> Enum.uniq()
    |> Enum.chunk_every(1000)
    |> Enum.flat_map(fn file_ids ->
      from(f in File, where: f.id in ^file_ids, select: {f.id, f.content_changed_at})
      |> Repo.all()
    end)
    |> Map.new()
  end

  defp preset_ids, do: Enum.map(Preset.list(), &to_string(&1.id))
end
