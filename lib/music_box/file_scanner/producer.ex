defmodule MusicBox.FileScanner.Producer do
  use GenStage

  alias MusicBox.FileScanner.{Entry, State}

  def start_link(init, opts \\ []) do
    GenStage.start_link(__MODULE__, init, opts)
  end

  @impl true
  def init(path) do
    {:producer, %State{entries: [to_entry(path)]}}
  end

  @impl true
  def handle_call({:walk, entries}, _from, state) do
    state = %{state | entries: entries ++ state.entries}
    current_demand = state.demand
    {entries, state} = get_entries(state, current_demand)
    {:reply, :ok, entries, %{state | demand: current_demand}}
  end

  @impl true
  def handle_demand(demand, state) when demand > 0 do
    {entries, state} = get_entries(state, demand)
    {:noreply, entries, state}
  end

  defp get_entries(state, demand) do
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
    {entries, %{state | demand: remaining, entries: remaining_entries}}
  end

  defp walk(%Entry{is_dir: false} = entry), do: [entry]

  defp walk(%Entry{path: path, is_dir: true}) do
    File.ls!(path)
    |> Enum.sort()
    |> Enum.map(&Path.join(path, &1))
    |> Enum.map(&to_entry/1)
  end

  defp to_entry(path) when is_binary(path) do
    %Entry{path: path, is_dir: File.dir?(path)}
  end
end
