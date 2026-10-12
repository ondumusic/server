defmodule Ondu.FileScanner.PeriodicWorker do
  @moduledoc false
  use GenServer

  alias Ondu.FileScanner
  alias Ondu.Settings

  @spec start_link(Keyword.t()) :: {:ok, pid()}
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @spec scan(scan_type :: FileScanner.scan_type()) :: :ok
  def scan(scan_type \\ nil) do
    GenServer.cast(__MODULE__, {:scan, scan_type})
  end

  @impl true
  def init(_) do
    default_state = %{
      timer: nil
    }

    # Only schedule the worker when not testing.
    state =
      if Ondu.env() != :test,
        do: schedule_worker(default_state, 1_000),
        else: default_state

    {:ok, state}
  end

  @impl true
  def handle_cast({:scan, scan_type}, state) do
    {:noreply, do_scan(state, scan_type)}
  end

  @impl true
  def handle_info(:scan, state) do
    {:noreply, do_scan(state)}
  end

  defp do_scan(state, scan_type \\ nil) do
    case FileScanner.scan(scan_type) do
      {:ok, :scan_completed} -> schedule_worker(state)
      {:error, :already_running} -> schedule_worker(state)
      # Retried with the next regular scan, not right away.
      {:error, :music_path_unavailable} -> schedule_worker(state)
      _error -> schedule_worker(state, 5_000)
    end
  end

  defp schedule_worker(default_state, interval_ms \\ nil) do
    if ref = default_state.timer,
      do: Process.cancel_timer(ref)

    settings = Settings.get()

    interval_ms =
      if interval_ms,
        do: interval_ms,
        else: :timer.minutes(settings.poll_interval)

    if settings.music_path do
      ref = Process.send_after(self(), :scan, interval_ms)
      %{default_state | timer: ref}
    else
      default_state
    end
  end
end
