defmodule MusicBox.FileScanner do
  @moduledoc false

  alias MusicBox.Files.File
  alias MusicBox.FileScanner.Agent
  alias MusicBox.FileScanner.Analyzer
  alias MusicBox.FileScanner.Operations
  alias MusicBox.FileScanner.PeriodicWorker
  alias MusicBox.Repo
  alias MusicBox.Settings
  alias MusicBox.Storage
  alias MusicBox.Utils

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
      {:error, :music_path_unavailable}
    else
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
      &safe_apply({Analyzer, :analyze, [&1]}),
      max_concurrency: 5,
      ordered: false,
      # This timeout is only used as a fallback, the probing tool has its own
      # shorter timeout which also stops ffprobe.
      timeout: 10_000,
      on_timeout: :kill_task
    )
    |> Stream.flat_map(&discard_errors/1)
    |> Stream.chunk_every(20)
    |> Enum.reduce(missing_file_ids, &batch_insert/2)
    |> MapSet.to_list()
    |> Operations.delete_files()

    Operations.broadcast(:deleted, started_at)

    Agent.stop()
    Operations.broadcast(:completed)

    {:ok, :scan_completed}
  rescue
    error ->
      Agent.stop()
      error
  end

  defp batch_insert(batch, missing_file_ids) do
    case safe_apply({Operations, :batch_insert, [batch, missing_file_ids]}) do
      {:ok, results} ->
        safe_apply({Operations, :broadcast, [:batch, results]})
        MapSet.difference(missing_file_ids, MapSet.new(results.moved_files))

      _error ->
        missing_file_ids
    end
  end

  # Cover files are not analyzed like music files, they are collected and dealt
  # with once the walk has completed using `Stream.transform/5`.
  defp handle_cover_files(walker) do
    Stream.transform(
      walker,
      fn -> [] end,
      fn entry, cover_files ->
        if MusicBox.Utils.cover_file?(entry.path),
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

  defp discard_errors({:ok, {:error, _error}}), do: []
  defp discard_errors({:ok, {:ok, result}}), do: [result]
  defp discard_errors({:ok, result}), do: [result]
  defp discard_errors({:exit, _reason}), do: []

  defp safe_apply({m, f, a}) do
    apply(m, f, a)
  rescue
    error -> {:error, error}
  end
end
