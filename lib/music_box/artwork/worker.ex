defmodule MusicBox.Artwork.Worker do
  @moduledoc false

  use GenServer

  alias MusicBox.Albums.Album
  alias MusicBox.Artwork
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
    default_state = %{}
    Phoenix.PubSub.subscribe(MusicBox.PubSub, "library:sync")
    {:ok, next_batch(default_state)}
  end

  @impl true
  def handle_info(%{topic: "library:sync", event: "processed", payload: payload}, state) do
    state =
      if Map.get(payload, :albums, []) != [],
        do: next_batch(state),
        else: state

    {:noreply, state}
  end

  def handle_info(:next_batch, state) do
    {:noreply, next_batch(state)}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    new_state = Map.delete(state, ref)

    if reason == :normal do
      {:noreply, next_batch(new_state)}
    else
      # Delay so a crashing album does not immediately get picked up again.
      Process.send_after(self(), :next_batch, @retry_after)
      {:noreply, new_state}
    end
  end

  def handle_info(_payload, state), do: {:noreply, state}

  defp next_batch(state) do
    batch_size = max(0, @max_concurrency - map_size(state))
    in_progress_ids = Enum.map(state, fn {_ref, album} -> album.id end)
    new_batch = if batch_size == 0, do: [], else: get_next_batch(batch_size, in_progress_ids)

    for album <- new_batch, into: state do
      {start_async_fetcher(album), album}
    end
  end

  # The batcher sorts albums without artwork first, then invalidated artwork
  # that needs to be refreshed.
  defp get_next_batch(len, exclude_ids) do
    from(
      al in Album,
      left_join: art in assoc(al, :artwork),
      left_join: artist in assoc(al, :artist),
      where:
        is_nil(art.album_id) or (not is_nil(art.path) and is_nil(art.hash)) or
          art.invalidated_at > art.last_fetch_attempt,
      where: al.id not in ^exclude_ids,
      preload: [artwork: art],
      order_by: [desc: is_nil(art.album_id), asc: artist.sort_name, asc: al.sort_name],
      limit: ^len
    )
    |> Repo.all()
  end

  defp start_async_fetcher(album) do
    {_pid, ref} = spawn_monitor(fn -> Artwork.find(album) end)
    ref
  end
end
