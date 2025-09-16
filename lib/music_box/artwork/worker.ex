defmodule MusicBox.Artwork.Worker do
  use GenServer

  alias MusicBox.Albums.Album
  alias MusicBox.Artwork
  alias MusicBox.Repo
  import Ecto.Query

  @max_concurrency 2
  @interval_ms :timer.seconds(2)

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    default_state = []
    {:ok, schedule_next_batch(default_state)}
  end

  def work do
    GenServer.cast(__MODULE__, :next_batch)
  end

  @impl true
  def handle_cast(:next_batch, state) do
    {:noreply, next_batch(state)}
  end

  @impl true
  def handle_info(:next_batch, state) do
    {:noreply, next_batch(state)}
  end

  def handle_info({:processed, album}, state) do
    new_state = Enum.reject(state, &(&1.id == album.id))
    {:noreply, schedule_next_batch(new_state)}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    Process.demonitor(ref)
    {:noreply, state}
  end

  defp next_batch(state) do
    batch_size = max(0, @max_concurrency - length(state))
    new_batch = if batch_size == 0, do: [], else: get_next_batch(batch_size)

    for album <- new_batch do
      start_async_fetcher(album)
    end

    state ++ new_batch
  end

  defp get_next_batch(len) do
    available_fetchers = MusicBox.Albums.Artwork.fetchers()
    last_fetcher = List.last(available_fetchers)

    from(
      a in Album,
      left_join: art in assoc(a, :artwork),
      left_join: artist in assoc(a, :artist),
      where: is_nil(art.path) and (is_nil(art.fetcher) or art.fetcher != ^last_fetcher),
      preload: [artwork: art],
      order_by: [asc_nulls_first: art.last_fetch_attempt, asc: artist.name, asc: a.name],
      limit: ^len
    )
    |> Repo.all()
  end

  defp start_async_fetcher(album) do
    myself = self()

    Task.start(fn ->
      Artwork.find(album)
      send(myself, {:processed, album})
    end)
  end

  defp schedule_next_batch(state) do
    Process.send_after(self(), :next_batch, @interval_ms)
    state
  end
end
