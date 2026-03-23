defmodule MusicBox.FileScanner do
  @moduledoc false

  alias MusicBox.FileScanner.Agent
  alias MusicBox.FileScanner.Analyzer
  alias MusicBox.FileScanner.Operations
  alias MusicBox.FileScanner.PeriodicWorker
  alias MusicBox.Settings

  @type scan_type :: :full | :quick | nil
  @type scan_error :: :missing_music_path | :already_running | :unknown_error
  @spec scan(scan_type :: scan_type()) :: {:ok, :scan_completed} | {:error, scan_error()}
  def scan(scan_type \\ nil) do
    with %Settings{music_path: "" <> _path} <- Settings.get(),
         {:agent, false} <- {:agent, Agent.running?()} do
      do_start(scan_type)
    else
      %Settings{} -> {:error, :missing_music_path}
      {:agent, true} -> {:error, :already_running}
    end
  end

  @spec scan(scan_type :: scan_type()) :: {:ok, :scan_started} | {:error, scan_error()}
  def scan_async(scan_type) do
    with %Settings{music_path: "" <> _path} <- Settings.get(),
         {:agent, false} <- {:agent, Agent.running?()},
         :ok <- PeriodicWorker.scan(scan_type) do
      {:ok, :scan_started}
    else
      %Settings{} -> {:error, :missing_music_path}
      {:agent, true} -> {:error, :already_running}
      _error -> {:error, :unknown_error}
    end
  end

  defp do_start(scan_type) do
    settings = Settings.get()

    scan_type = scan_type || settings.scan_type
    Agent.start(scan_type)

    started_at = DateTime.utc_now()

    Operations.find_deleted_files()

    # NOTE: / is relative to settings.music_path
    walker = MusicBox.Storage.walk("/")

    walker =
      if scan_type == :quick,
        do: skip_existing_files(walker),
        else: walker

    walker
    |> Task.async_stream(
      &safe_apply({Analyzer, :analyze, [&1]}),
      max_concurrency: 5,
      ordered: false,
      timeout: 5_000,
      on_timeout: :kill_task
    )
    |> Stream.flat_map(&discard_errors/1)
    |> Stream.chunk_every(20)
    |> Stream.map(&safe_apply({Operations, :batch_insert, [&1]}))
    |> Stream.flat_map(&discard_errors/1)
    |> Stream.each(&safe_apply({Operations, :broadcast, [:batch, &1]}))
    |> Stream.run()

    Operations.broadcast(:deleted, started_at)

    Agent.stop()
    Operations.broadcast(:completed)

    {:ok, :scan_completed}
  rescue
    error ->
      Agent.stop()
      error
  end

  defp skip_existing_files(enum) do
    enum
    |> Stream.chunk_every(50)
    |> Stream.flat_map(fn files ->
      all_paths = Enum.map(files, & &1.path)
      existing_paths = Operations.find_existing_paths(all_paths)
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
