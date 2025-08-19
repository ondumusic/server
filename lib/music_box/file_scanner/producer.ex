defmodule MusicBox.FileScanner.Producer do
  use GenStage

  alias MusicBox.FileScanner.{Entry, State}
  alias MusicBox.Settings

  def start_link(init, opts \\ []) do
    GenStage.start_link(__MODULE__, init, opts)
  end

  @impl true
  def init(opts) do
    auto_start = Keyword.get(opts, :auto_start, true)

    if auto_start,
      do: send(self(), :start_scan)

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
  def handle_info(:start_scan, state) do
    settings = Settings.get()
    new_entries = [to_entry(settings.music_path, settings.scan_type)]
    {entries, state} = get_entries(state, state.demand, new_entries)
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
    File.ls!(path)
    |> Enum.sort()
    |> Enum.map(&Path.join(path, &1))
    |> Enum.map(&to_entry(&1, scan_type))
  end

  defp to_entry(path, scan_type) when is_binary(path) do
    %Entry{path: path, is_dir: File.dir?(path), scan_type: scan_type}
  end

  defp schedule_poll(%State{poll_timer: timer_ref} = state) do
    poll_minutes = Settings.get().poll_interval
    poll_ms = poll_minutes * 60 * 1_000

    if timer_ref,
      do: Process.cancel_timer(timer_ref)

    timer_ref = Process.send_after(self(), :start_scan, poll_ms)
    %{state | poll_timer: timer_ref}
  end
end
