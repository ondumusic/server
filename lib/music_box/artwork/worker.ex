defmodule MusicBox.Artwork.Worker do
  @moduledoc false

  use GenServer

  alias MusicBox.Albums
  alias MusicBox.Albums.Album
  alias MusicBox.Repo
  import Ecto.Query

  @max_concurrency 2
  @retry_after :timer.seconds(30)

  @spec start_link(Keyword.t()) :: {:ok, pid()}
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    Phoenix.PubSub.subscribe(MusicBox.PubSub, "library:sync")
    {:ok, next_batch(%{running: %{}, crashed: []})}
  end

  @impl true
  def handle_info(%{topic: "library:sync", event: "processed", payload: payload}, state) do
    state =
      if Map.get(payload, :albums, []) != [],
        do: next_batch(state),
        else: state

    {:noreply, state}
  end

  # Cover files are only compared once a scan completed, which might not have
  # changed any albums itself.
  def handle_info(%{topic: "library:sync", event: "completed"}, state) do
    {:noreply, next_batch(state)}
  end

  def handle_info(:next_batch, state) do
    {:noreply, next_batch(state)}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    {album_id, running} = Map.pop(state.running, ref)
    state = %{state | running: running}

    if reason == :normal do
      {:noreply, next_batch(state)}
    else
      # If the process crashed we will skip this album until the server has
      # been restarted, this should avoid infinite crash loops. Maybe we'll
      # do a more permanent solution at a later time.
      Process.send_after(self(), :next_batch, @retry_after)
      {:noreply, %{state | crashed: [album_id | state.crashed]}}
    end
  end

  def handle_info(_payload, state), do: {:noreply, state}

  defp next_batch(state) do
    batch_size = max(0, @max_concurrency - map_size(state.running))
    exclude_ids = Map.values(state.running) ++ state.crashed
    new_batch = if batch_size == 0, do: [], else: get_next_batch(batch_size, exclude_ids)

    running =
      for album <- new_batch, into: state.running do
        {start_async_fetcher(album), album.id}
      end

    %{state | running: running}
  end

  # The batcher sorts albums without artwork first, then invalidated artwork
  # that needs to be refreshed.
  defp get_next_batch(len, exclude_ids) do
    from(
      al in Album,
      left_join: art in assoc(al, :artwork),
      left_join: artist in assoc(al, :artist),
      where: is_nil(art.album_id) or art.invalidated_at > art.last_fetch_attempt,
      where: al.id not in ^exclude_ids,
      preload: [artwork: art],
      order_by: [desc: is_nil(art.album_id), asc: artist.sort_name, asc: al.sort_name],
      limit: ^len
    )
    |> Repo.all()
  end

  defp start_async_fetcher(album) do
    {_pid, ref} = spawn_monitor(fn -> Albums.find_cover(album) end)
    ref
  end
end
