defmodule MusicBox.Loudness.Worker do
  @moduledoc """
  Measures the loudness of all files that have not been measured yet, or whose
  content changed after they were measured.

  It always does new files first, then files are picked in path order so the
  tracks of an album are usually measured together
  """

  use GenServer

  alias MusicBox.Files.File
  alias MusicBox.Loudness
  alias MusicBox.Repo

  import Ecto.Query

  @max_concurrency 2
  @retry_after :timer.seconds(30)

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    Phoenix.PubSub.subscribe(MusicBox.PubSub, "library:sync")
    {:ok, next_batch(%{running: %{}, crashed: []})}
  end

  @impl true
  def handle_info(%{topic: "library:sync", event: "processed"}, state) do
    {:noreply, next_batch(state)}
  end

  def handle_info(:next_batch, state) do
    {:noreply, next_batch(state)}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    {file_id, running} = Map.pop(state.running, ref)
    state = %{state | running: running}

    if reason == :normal do
      {:noreply, next_batch(state)}
    else
      # Delay so a crashing environment (e.g. missing ffmpeg) does not spin
      Process.send_after(self(), :next_batch, @retry_after)
      {:noreply, %{state | crashed: [file_id | state.crashed]}}
    end
  end

  def handle_info(_payload, state), do: {:noreply, state}

  defp next_batch(state) do
    batch_size = max(0, @max_concurrency - map_size(state.running))
    exclude_ids = Map.values(state.running) ++ state.crashed
    new_batch = if batch_size == 0, do: [], else: get_next_batch(batch_size, exclude_ids)

    running =
      for file <- new_batch, into: state.running do
        {start_async_measure(file), file.id}
      end

    %{state | running: running}
  end

  defp get_next_batch(len, exclude_ids) do
    from(f in File,
      where:
        is_nil(f.loudness) or
          fragment("json_extract(?, '$.measured_at') < ?", f.loudness, f.content_changed_at),
      where: f.id not in ^exclude_ids,
      order_by: [desc: is_nil(f.loudness), asc: f.path],
      limit: ^len
    )
    |> Repo.all()
  end

  defp start_async_measure(file) do
    {_pid, ref} = spawn_monitor(fn -> Loudness.measure(file) end)
    ref
  end
end
