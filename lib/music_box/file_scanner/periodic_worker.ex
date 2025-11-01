defmodule MusicBox.FileScanner.PeriodicWorker do
  @moduledoc false
  use GenServer

  alias MusicBox.Settings
  alias MusicBox.FileScanner

  @spec start_link(Keyword.t()) :: {:ok, pid()}
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    default_state = %{
      timer: nil
    }

    {:ok, schedule_worker(default_state, 1_000)}
  end

  @impl true
  def handle_info(:scan, state) do
    state =
      case FileScanner.scan() do
        {:ok, :scan_completed} -> schedule_worker(state)
        {:error, :already_running} -> schedule_worker(state)
        _error -> schedule_worker(state, 5_000)
      end

    {:noreply, state}
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
