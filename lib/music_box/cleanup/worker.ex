defmodule MusicBox.Cleanup.Worker do
  @moduledoc false

  use GenServer

  alias MusicBox.Albums.Album
  alias MusicBox.Artists.Artist
  alias MusicBox.Cleanup
  alias MusicBox.FileScanner.Utils
  alias MusicBox.Playlists.{Playlist, PlaylistItem}
  alias MusicBox.Repo
  alias MusicBox.Settings
  alias MusicBox.Tracks.Track
  alias MusicBox.Transcoder.CacheCleanup

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
    Cleanup.work_async(:all)
    {:noreply, state}
  end

  def handle_info(_payload, state), do: {:noreply, state}

  def do_step(:transcode_cache) do
    CacheCleanup.run()
  end

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
      started_at = DateTime.utc_now()

      # Then update those that have albums
      subquery =
        from(a in Artist,
          left_join: al in Album,
          on: al.artist_id == a.id,
          group_by: a.id,
          select: %{artist_id: a.id, count: count(al.id)}
        )

      {count, _} =
        from(a in Artist,
          join: s in subquery(subquery),
          on: a.id == s.artist_id,
          where: a.album_count != s.count or is_nil(a.album_count),
          update: [set: [album_count: s.count, updated_at: ^started_at]]
        )
        |> repo.update_all([])

      if count > 0 do
        updated_artist_ids =
          from(a in Artist,
            where: a.updated_at >= ^started_at,
            select: a.id
          )
          |> Repo.all()

        MusicBoxWeb.Endpoint.broadcast!("library:sync", "processed", %{
          artists: updated_artist_ids
        })
      end

      {:ok, :noop}
    end)
  end

  def do_step(:update_track_counts) do
    Repo.transact(fn repo ->
      started_at = DateTime.utc_now()

      # Then update to get a track count per album
      subquery =
        from(al in Album,
          left_join: t in Track,
          on: t.album_id == al.id,
          group_by: al.id,
          select: %{album_id: al.id, count: count(t.id)}
        )

      {count, _} =
        from(al in Album,
          join: s in subquery(subquery),
          on: al.id == s.album_id,
          where: al.track_count != s.count or is_nil(al.track_count),
          update: [set: [track_count: s.count, updated_at: ^started_at]]
        )
        |> repo.update_all([])

      if count > 0 do
        updated_album_ids =
          from(al in Album,
            where: al.updated_at >= ^started_at,
            select: al.id
          )
          |> Repo.all()

        MusicBoxWeb.Endpoint.broadcast!("library:sync", "processed", %{albums: updated_album_ids})
      end

      {:ok, :noop}
    end)
  end

  def do_step(:update_playlist_counts) do
    Repo.transact(fn repo ->
      started_at = DateTime.utc_now()

      # Then update to get a item count per playlist
      subquery =
        from(p in Playlist,
          left_join: pi in PlaylistItem,
          on: pi.playlist_id == p.id,
          group_by: p.id,
          select: %{playlist_id: p.id, count: count(pi.id)}
        )

      {count, _} =
        from(p in Playlist,
          join: s in subquery(subquery),
          on: p.id == s.playlist_id,
          where: p.track_count != s.count or is_nil(p.track_count),
          update: [set: [track_count: s.count, updated_at: ^started_at]]
        )
        |> repo.update_all([])

      if count > 0 do
        updated_playlist_ids =
          from(p in Playlist,
            where: p.updated_at >= ^started_at,
            select: p.id
          )
          |> Repo.all()

        MusicBoxWeb.Endpoint.broadcast!("library:sync", "processed", %{
          playlists: updated_playlist_ids
        })
      end

      {:ok, :noop}
    end)
  end

  def do_step(:update_fts) do
    Repo.query!("INSERT INTO artists_fts(artists_fts) VALUES('rebuild');")
    Repo.query!("INSERT INTO albums_fts(albums_fts) VALUES('rebuild');")
    Repo.query!("INSERT INTO tracks_fts(tracks_fts) VALUES('rebuild');")
  end

  defp cleanup_unused_albums do
    from(al in Album,
      as: :album,
      where: not exists(from t in Track, where: t.album_id == parent_as(:album).id)
    )
    |> Repo.delete_all()
  end

  defp cleanup_unused_artists do
    from(a in Artist,
      as: :artist,
      where: not exists(from t in Track, where: t.artist_id == parent_as(:artist).id),
      where: not exists(from al in Album, where: al.artist_id == parent_as(:artist).id)
    )
    |> Repo.delete_all()
  end

  defp update_sort_names(schema, strip_prefixes) do
    Repo.transact(
      fn repo ->
        started_at = DateTime.utc_now()

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

        updated_ids =
          from(s in schema,
            where: s.updated_at >= ^started_at,
            select: s.id
          )
          |> Repo.all()

        MusicBoxWeb.Endpoint.broadcast!("library:sync", "processed", %{
          albums: updated_ids,
          artists: updated_ids
        })

        {:ok, nil}
      end,
      timeout: 30_000
    )
  end
end
