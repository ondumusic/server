defmodule MusicBox.Artwork.Worker do
  @moduledoc false

  use GenServer

  alias MusicBox.Albums.Album
  alias MusicBox.Artwork
  alias MusicBox.Repo
  alias MusicBox.Tracks.Track
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

  # Newly found albums should come first, changed albums last.
  defp get_next_batch(len, exclude_ids) do
    new_albums = albums_query(exclude_ids, missing_artwork()) |> limit(^len) |> Repo.all()
    remaining = len - length(new_albums)

    if remaining > 0 do
      stale_albums = albums_query(exclude_ids, changed_files()) |> limit(^remaining)
      new_albums ++ Repo.all(stale_albums)
    else
      new_albums
    end
  end

  defp albums_query(exclude_ids, condition) do
    from(
      al in Album,
      as: :album,
      left_join: art in assoc(al, :artwork),
      as: :artwork,
      left_join: artist in assoc(al, :artist),
      where: ^condition,
      where: al.id not in ^exclude_ids,
      preload: [artwork: art],
      order_by: [asc: artist.sort_name, asc: al.sort_name]
    )
  end

  defp missing_artwork do
    dynamic(
      [artwork: art],
      is_nil(art.album_id) or (not is_nil(art.path) and is_nil(art.hash))
    )
  end

  defp changed_files do
    changed_files =
      from(t in Track,
        join: f in assoc(t, :file),
        where: t.album_id == parent_as(:album).id,
        where: f.content_changed_at > parent_as(:artwork).last_fetch_attempt,
        select: 1
      )

    dynamic([artwork: art], not is_nil(art.album_id) and exists(changed_files))
  end

  defp start_async_fetcher(album) do
    {_pid, ref} = spawn_monitor(fn -> Artwork.find(album) end)
    ref
  end
end
