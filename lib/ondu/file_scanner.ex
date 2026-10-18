defmodule Ondu.FileScanner do
  @moduledoc false

  alias Ondu.Albums
  alias Ondu.Files.File

  alias Ondu.FileScanner.Agent
  alias Ondu.FileScanner.Analyzer
  alias Ondu.FileScanner.{Applier, Deletions, Operations, Plan, Planner}
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

    # If the library is empty there is nothing that could have been moved, renamed
    # etc. So we can just save everything immediately without running all the checks.
    library_empty? = not Repo.exists?(File)

    scan_type
    |> walk(library_empty?)
    |> reconcile()
    |> log_summary(scan_type, started_at)

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

  # Walks the music path and analyzes every file it finds. It will then
  # either save instantly (in batches) or defer the file for reconciliation
  # which happens only after the initial walk has completed.
  defp walk(scan_type, library_empty?) do
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
    |> Enum.reduce([], &save_or_defer(&1, &2, library_empty?))
    |> Enum.reverse()
    |> List.flatten()
  end

  # When the library is empty we can instantly save all files in this batch.
  defp save_or_defer(batch, deferred, true) do
    Operations.save_batch(batch)
    deferred
  end

  # When the library is not empty this function will check each file to
  # determine whether or not the file needs to be deferred or can be
  # inserted immediately.
  defp save_or_defer(batch, deferred, false) do
    known_metadata = Operations.find_known_metadata(batch)

    {deferred_files, saved_files} =
      Enum.split_with(batch, &Planner.needs_plan?(&1, known_metadata))

    Operations.save_batch(saved_files)
    [deferred_files | deferred]
  end

  # Once the walk has completed we know which files are really gone, so we can
  # figure out what happened to them and to the deferred files. Were they moved,
  # replaced, deleted or part of a renamed album or artist?
  defp reconcile(deferred) do
    missing_file_ids = Deletions.find_missing_files()
    plan = Planner.plan(deferred, missing_file_ids)
    :ok = Applier.apply(plan)
    plan
  end

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
        Albums.invalidate_cover_files(cover_files)
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
  defp log_summary(%Plan{} = plan, scan_type, started_at) do
    since = DateTime.truncate(started_at, :second)
    added = Repo.aggregate(from(f in File, where: f.inserted_at >= ^since), :count)

    updated =
      from(f in File, where: f.content_changed_at >= ^since and f.inserted_at < ^since)
      |> Repo.aggregate(:count)

    moved = length(plan.moved_files)
    removed = length(plan.deleted_files)

    seconds = Float.round(DateTime.diff(DateTime.utc_now(), started_at, :millisecond) / 1000, 1)

    Logger.info(
      "Scan completed (#{scan_type}) in #{seconds}s: " <>
        "#{added} added, #{updated} updated, #{moved} moved, #{removed} removed"
    )
  end
end
