defmodule Ondu.FileScanner do
  @moduledoc false

  alias Ondu.Files.File
  alias Ondu.FileScanner.Agent
  alias Ondu.FileScanner.Analyzer
  alias Ondu.FileScanner.Operations
  alias Ondu.FileScanner.PeriodicWorker
  alias Ondu.Notices
  alias Ondu.Repo
  alias Ondu.Settings
  alias Ondu.Storage
  alias Ondu.Utils

  import Ecto.Query, only: [from: 2]

  require Logger

  @type scan_type :: :full | :quick | nil
  @type scan_error ::
          :music_path_missing | :music_path_unavailable | :already_running | :unknown_error
  @spec scan(scan_type :: scan_type()) :: {:ok, :scan_completed} | {:error, scan_error()}
  def scan(scan_type \\ nil) do
    with %Settings{music_path: "" <> _path} <- Settings.get(),
         {:agent, false} <- {:agent, Agent.running?()},
         :ok <- ensure_music_path_available() do
      do_start(scan_type)
    else
      %Settings{} -> {:error, :music_path_missing}
      {:agent, true} -> {:error, :already_running}
      {:error, :music_path_unavailable} = error -> error
    end
  end

  @spec scan(scan_type :: scan_type()) :: {:ok, :scan_started} | {:error, scan_error()}
  def scan_async(scan_type) do
    with %Settings{music_path: "" <> _path} <- Settings.get(),
         {:agent, false} <- {:agent, Agent.running?()},
         :ok <- PeriodicWorker.scan(scan_type) do
      {:ok, :scan_started}
    else
      %Settings{} -> {:error, :music_path_missing}
      {:agent, true} -> {:error, :already_running}
      _error -> {:error, :unknown_error}
    end
  end

  # When the music path is not available (e.g. an unmounted network share) it is
  # usually an empty directory and the scanner would mark all files as deleted.
  # This would also delete all data linked to them (plays, playlist items, ...)
  # because putting the files back would make them new files with new ids. So
  # when there is no music at all, but there was before, nothing is scanned.
  defp ensure_music_path_available do
    if Repo.exists?(File) and not has_music?() do
      Logger.warning("No music found in the music path, not scanning in case it is unavailable")
      Notices.raise_notice(:library_unavailable)
      {:error, :music_path_unavailable}
    else
      Notices.resolve_notice(:library_unavailable)
      :ok
    end
  end

  # Walks the music path until it finds the first music file, if it finds one
  # we assume the music path is present/available.
  defp has_music? do
    Storage.walk("/")
    |> Stream.filter(&Utils.valid_extname?(&1.path))
    |> Enum.take(1)
    |> Enum.any?()
  end

  defp do_start(scan_type) do
    settings = Settings.get()

    scan_type = scan_type || settings.scan_type
    Agent.start(scan_type)
    Logger.info("Scan started (#{scan_type})")

    started_at = DateTime.utc_now()

    # Missing files are found before the walk and only deleted after it.
    missing_file_ids = Operations.find_missing_files() |> MapSet.new()

    # NOTE: / is relative to settings.music_path
    walker =
      Storage.walk("/")
      |> handle_cover_files()

    walker =
      if scan_type == :quick,
        do: skip_existing_files(walker),
        else: walker

    walker
    |> Task.async_stream(
      &analyze/1,
      max_concurrency: 5,
      ordered: false,
      # This timeout is only used as a fallback, the probing tool has its own
      # shorter timeout which also stops ffprobe.
      timeout: 10_000,
      on_timeout: :kill_task,
      zip_input_on_exit: true
    )
    |> Stream.flat_map(&discard_errors/1)
    |> Stream.chunk_every(20)
    |> Enum.reduce({missing_file_ids, []}, &batch_insert/2)
    |> insert_possible_replacements()
    |> MapSet.to_list()
    |> Operations.delete_files()
    |> log_summary(scan_type, started_at)

    # This will ensure any renamed album preserves its existing record instead
    # of the newly inserted one.
    case safe_apply({Operations, :keep_renamed_albums, []}) do
      {:ok, _album_ids} -> :ok
      error -> Logger.error("Failed to keep renamed albums (#{batch_error(error)})")
    end

    Operations.broadcast(:deleted, started_at)

    Agent.stop()
    Operations.broadcast(:completed)

    {:ok, :scan_completed}
  rescue
    error ->
      Logger.error("Scan failed: " <> Exception.format(:error, error, __STACKTRACE__))
      Agent.stop()
      {:error, :unknown_error}
  end

  # Batch insert new files, this also uses missing_file_ids to detect if any
  # files have moved, and collects possible replacement candidates to process
  # after all batches have been inserted.
  defp batch_insert(batch, {missing_file_ids, possible_replacements}) do
    case safe_apply({Operations, :batch_insert, [batch, missing_file_ids]}) do
      {:ok, results} ->
        safe_apply({Operations, :broadcast, [:batch, results]})
        missing_file_ids = MapSet.difference(missing_file_ids, MapSet.new(results.moved_files))
        {missing_file_ids, possible_replacements ++ results.possible_replacements}

      error ->
        paths = Enum.map_join(batch, "\n", & &1.path)
        Logger.error("Failed to save scanned files (#{batch_error(error)}):\n#{paths}")
        {missing_file_ids, possible_replacements}
    end
  end

  # The possible replacements are inserted after all batches have been inserted
  # in order to determine whether these were retagged or reencoded files. The
  # replaced files are no longer missing, so it returns only the remaining
  # missing ones to be cleaned up next.
  defp insert_possible_replacements({missing_file_ids, possible_replacements}) do
    replaced_file_ids =
      case safe_apply({Operations, :replace_files, [possible_replacements, missing_file_ids]}) do
        {:ok, file_ids} ->
          file_ids

        error ->
          Logger.error("Failed to replace files (#{batch_error(error)})")
          []
      end

    possible_replacements
    |> Enum.chunk_every(20)
    |> Enum.each(&batch_insert(&1, {MapSet.new(), []}))

    MapSet.difference(missing_file_ids, MapSet.new(replaced_file_ids))
  end

  defp batch_error({:error, step, reason, _changes}), do: "#{step}: #{inspect(reason)}"
  defp batch_error({:error, exception}), do: Exception.message(exception)

  # Cover files are not analyzed like music files, they are collected and dealt
  # with once the walk has completed using `Stream.transform/5`.
  defp handle_cover_files(walker) do
    Stream.transform(
      walker,
      fn -> [] end,
      fn entry, cover_files ->
        if Ondu.Utils.cover_file?(entry.path),
          do: {[], [entry | cover_files]},
          else: {[entry], cover_files}
      end,
      fn cover_files ->
        Operations.invalidate_cover_files(cover_files)
        {[], cover_files}
      end,
      fn _cover_files -> :ok end
    )
  end

  defp skip_existing_files(enum) do
    enum
    |> Stream.chunk_every(50)
    |> Stream.flat_map(fn files ->
      existing_paths = Operations.find_unchanged_paths(files)
      Enum.reject(files, &Enum.member?(existing_paths, &1.path))
    end)
  end

  # We are using a new function for this instead of `safe_apply/1` so we can add
  # a log message when the analyzer crashes. In most cases the analyzer itself
  # should return cleanly and log relevant things itself, so this is an edge case.
  defp analyze(file) do
    Analyzer.analyze(file)
  rescue
    error ->
      Logger.warning("Skipped #{file.path}, analyzing failed (#{Exception.message(error)})")
      {:error, :analyzing_failed}
  end

  defp discard_errors({:ok, {:error, _error}}), do: []
  defp discard_errors({:ok, {:ok, result}}), do: [result]

  defp discard_errors({:exit, {file, reason}}) do
    Logger.warning("Skipped #{file.path}, analyzing did not finish (#{inspect(reason)})")
    []
  end

  # Timestamps are stored in seconds, so this will count anything since the
  # second the scan started and was added or updated by it.
  defp log_summary({:ok, removed}, scan_type, started_at) do
    since = DateTime.truncate(started_at, :second)
    added = Repo.aggregate(from(f in File, where: f.inserted_at >= ^since), :count)

    updated =
      from(f in File, where: f.content_changed_at >= ^since and f.inserted_at < ^since)
      |> Repo.aggregate(:count)

    seconds = Float.round(DateTime.diff(DateTime.utc_now(), started_at, :millisecond) / 1000, 1)

    Logger.info(
      "Scan completed (#{scan_type}) in #{seconds}s: " <>
        "#{added} added, #{updated} updated, #{removed} removed"
    )
  end

  defp safe_apply({m, f, a}) do
    apply(m, f, a)
  rescue
    error -> {:error, error}
  end
end
