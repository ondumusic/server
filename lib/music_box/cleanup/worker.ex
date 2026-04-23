defmodule MusicBox.Cleanup.Worker do
  @moduledoc false

  use GenServer

  alias MusicBox.Albums.Album
  alias MusicBox.Artists.Artist
  alias MusicBox.Cleanup
  alias MusicBox.FileScanner.Utils
  alias MusicBox.Repo
  alias MusicBox.Settings
  alias MusicBox.Tracks.Track

  import Ecto.Query

  @spec start_link(Keyword.t()) :: {:ok, pid()}
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    default_state = []
    Phoenix.PubSub.subscribe(MusicBox.PubSub, "library:sync")
    {:ok, default_state}
  end

  def exec(step) do
    GenServer.call(__MODULE__, {:step, step})
  end

  def exec_async(step) do
    GenServer.cast(__MODULE__, {:step, step})
  end

  @impl true
  def handle_call({:step, step}, _from, state) do
    do_step(step)
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:step, step}, state) do
    do_step(step)
    {:noreply, state}
  end

  @impl true
  def handle_info(%{topic: "library:sync", event: "completed"}, state) do
    Cleanup.work_async([
      :unused,
      :update_album_counts,
      :update_track_counts,
      :sort_names,
      :update_fts
    ])

    {:noreply, state}
  end

  def handle_info(_payload, state), do: {:noreply, state}

  def do_step(:sort_names) do
    settings = Settings.get()
    update_sort_names(Artist, settings.strip_sort_prefixes)
    update_sort_names(Album, settings.strip_sort_prefixes)
  end

  def do_step(:unused) do
    cleanup_unused_albums()
    cleanup_unused_artists()
  end

  def do_step(:update_album_counts) do
    Repo.transact(fn repo ->
      # First, set all to 0
      from(a in Artist, update: [set: [album_count: 0]])
      |> repo.update_all([])

      # Then update those that have albums
      subquery =
        from(al in Album,
          group_by: al.artist_id,
          select: %{artist_id: al.artist_id, count: count(al.id)}
        )

      from(a in Artist,
        join: s in subquery(subquery),
        on: a.id == s.artist_id,
        update: [set: [album_count: s.count]]
      )
      |> repo.update_all([])

      {:ok, :noop}
    end)
  end

  def do_step(:update_track_counts) do
    Repo.transact(fn repo ->
      # First, set all to 0
      from(al in Album, update: [set: [track_count: 0]])
      |> repo.update_all([])

      # Then update to get a track count per album
      subquery =
        from(t in Track,
          group_by: t.album_id,
          select: %{album_id: t.album_id, count: count(t.id)}
        )

      from(al in Album,
        join: s in subquery(subquery),
        on: al.id == s.album_id,
        update: [set: [track_count: s.count]]
      )
      |> repo.update_all([])

      {:ok, :noop}
    end)
  end

  def do_step(:update_fts) do
    Repo.query!("INSERT INTO artists_fts(artists_fts) VALUES('rebuild');")
    Repo.query!("INSERT INTO albums_fts(albums_fts) VALUES('rebuild');")
    Repo.query!("INSERT INTO tracks_fts(tracks_fts) VALUES('rebuild');")
  end

  defp cleanup_unused_albums do
    known_albums_query = from(t in Track, select: t.album_id, group_by: t.album_id)

    from(al in Album,
      where: al.id not in subquery(known_albums_query)
    )
    |> Repo.delete_all()
  end

  defp cleanup_unused_artists do
    known_artists_query =
      from(t in Track, select: t.artist_id, group_by: t.artist_id)
      |> union_all(^from(al in Album, select: al.artist_id, group_by: al.artist_id))

    from(a in Artist,
      where: a.id not in subquery(known_artists_query)
    )
    |> Repo.delete_all()
  end

  defp update_sort_names(schema, strip_prefixes) do
    Repo.transact(
      fn repo ->
        schema
        |> repo.stream()
        |> Stream.each(fn entry ->
          sort_name = Utils.sort_name(entry.name, strip_prefixes: strip_prefixes)

          entry
          |> Ecto.Changeset.change()
          |> Ecto.Changeset.put_change(:sort_name, sort_name)
          |> repo.update!()
        end)
        |> Stream.run()

        {:ok, nil}
      end,
      timeout: 30_000
    )
  end
end
