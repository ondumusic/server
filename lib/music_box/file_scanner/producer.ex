defmodule MusicBox.FileScanner.Producer do
  @moduledoc false

  use GenStage

  alias MusicBox.FileScanner.{Entry, State}
  alias MusicBox.Settings

  require Logger

  def start_link(init, opts \\ []) do
    GenStage.start_link(__MODULE__, init, opts)
  end

  @impl true
  def init(opts) do
    auto_start = Keyword.fetch!(opts, :auto_start)

    if auto_start,
      do: send(self(), {:start_scan, []})

    {:producer, %State{}}
  end

  @impl true
  def handle_demand(demand, state) when demand > 0 do
    {entries, state} = get_entries(state, demand)
    {:noreply, entries, state}
  end

  @impl true
  def handle_call({:walk, new_entries}, _from, state) do
    {entries, state} = get_entries(state, state.demand, new_entries)
    {:reply, :ok, entries, state}
  end

  @impl true
  def handle_info({:start_scan, opts}, state) do
    settings = Settings.get()
    scan_type = Keyword.get(opts, :type, settings.scan_type)

    {entries, state} =
      if settings.music_path do
        new_entries = [to_entry(settings.music_path, scan_type)]
        get_entries(state, state.demand, new_entries)
      else
        {[], schedule_poll(state)}
      end

    {:noreply, entries, state}
  end

  defp get_entries(state, demand, prepend_entries \\ []) do
    # Potentially we have a request to prepend some new entries
    state =
      if prepend_entries != [],
        do: %{state | entries: prepend_entries ++ state.entries},
        else: state

    # Get N entries from the state
    {entries, remaining_entries} = Enum.split(state.entries, demand)

    # Walk the entry paths to find more files and/or directories
    # and append the remaining entries, then only take what we
    # need right now and store the rest in the state.
    {entries, remaining_entries} =
      entries
      |> Enum.flat_map(&walk/1)
      |> Kernel.++(remaining_entries)
      |> Enum.split(demand)

    # Determine the next demand (either remaining or the demand amount)
    # which we will store in the state for possible later usage.
    remaining =
      case demand - length(entries) do
        0 -> demand
        n -> n
      end

    # Return the found entries and updated state
    state = %{state | demand: remaining, entries: remaining_entries}
    {entries, schedule_poll(state)}
  end

  defp walk(%Entry{is_dir: false} = entry), do: [entry]

  defp walk(%Entry{path: path, is_dir: true, scan_type: scan_type}) do
    case File.ls(path) do
      {:ok, list} ->
        Logger.debug("Finding files in: #{path}")

        list
        |> Enum.sort()
        |> Enum.map(&Path.join(path, &1))
        |> Enum.map(&to_entry(&1, scan_type))

      _ ->
        Logger.error("Permission denied to: #{path}")
        []
    end
  end

  defp to_entry(path, scan_type) when is_binary(path) do
    %Entry{path: path, is_dir: File.dir?(path), scan_type: scan_type}
  end

  defp schedule_poll(%State{poll_timer: timer_ref} = state) do
    track_count =
      if state.entries == [],
        do: MusicBox.Repo.aggregate(MusicBox.Tracks.Track, :count, log: false)

    poll_minutes = Settings.get().poll_interval

    poll_ms =
      if track_count == 0,
        do: :timer.seconds(5),
        else: :timer.minutes(poll_minutes)

    if timer_ref,
      do: Process.cancel_timer(timer_ref)

    timer_ref = Process.send_after(self(), {:start_scan, []}, poll_ms)
    %{state | poll_timer: timer_ref}
  end
end
