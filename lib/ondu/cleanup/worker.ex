defmodule Ondu.Cleanup.Worker do
  @moduledoc false

  use GenServer

  alias Ondu.Albums.Album
  alias Ondu.Annotations
  alias Ondu.Artists.Artist
  alias Ondu.Artwork
  alias Ondu.Cleanup
  alias Ondu.Counters
  alias Ondu.FileScanner.Utils
  alias Ondu.Playlists.{Playlist, PlaylistItem}
  alias Ondu.Repo
  alias Ondu.Settings
  alias Ondu.Tracks.Track
  alias Ondu.Transcoder.CacheCleanup

  import Ecto.Query

  @spec start_link(Keyword.t()) :: {:ok, pid()}
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    default_state = []
    Phoenix.PubSub.subscribe(Ondu.PubSub, "library:sync")
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
    Artwork.remove_orphaned()
    Annotations.remove_orphaned()
  end

  def do_step(:update_album_counts) do
    Counters.update(Artist, :album_count, Album, :artist_id)
    |> broadcast_processed(:artists)
  end

  def do_step(:update_track_counts) do
    Counters.update(Album, :track_count, Track, :album_id)
    |> broadcast_processed(:albums)
  end

  def do_step(:update_playlist_counts) do
    Counters.update(Playlist, :track_count, PlaylistItem, :playlist_id)
    |> broadcast_processed(:playlists)
  end

  def do_step(:update_fts) do
    Repo.query!("INSERT INTO artists_fts(artists_fts) VALUES('rebuild');")
    Repo.query!("INSERT INTO albums_fts(albums_fts) VALUES('rebuild');")
    Repo.query!("INSERT INTO tracks_fts(tracks_fts) VALUES('rebuild');")
  end

  defp broadcast_processed([], _key), do: :ok

  defp broadcast_processed(ids, key) do
    OnduWeb.Endpoint.broadcast!("library:sync", "processed", %{key => ids})
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

        OnduWeb.Endpoint.broadcast!("library:sync", "processed", %{
          albums: updated_ids,
          artists: updated_ids
        })

        {:ok, nil}
      end,
      timeout: 30_000
    )
  end
end
