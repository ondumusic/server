# credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
defmodule MusicBox.FileScanner.Operations do
  @moduledoc false

  import Phoenix.Channel.Server, only: [broadcast: 4]

  alias Ecto.Multi
  alias MusicBox.Albums.{Album, Artwork, CoverFile}
  alias MusicBox.Artists.Artist
  alias MusicBox.Counters
  alias MusicBox.DeletionLog
  alias MusicBox.Files.{File, FileMetadata}
  alias MusicBox.FileScanner.{Analyzer, Utils}
  alias MusicBox.Repo
  alias MusicBox.Settings
  alias MusicBox.Storage
  alias MusicBox.Tracks.Track

  import Ecto.Query

  require Logger

  @spec batch_insert([Analyzer.Result.t()]) ::
          :noop
          | {:ok,
             %{
               artists: [Artist],
               albums: [Album],
               tracks: [Track],
               files: [File],
               counts: %{artists: [Ecto.UUID.t()], albums: [Ecto.UUID.t()]}
             }}
          | Ecto.Multi.failure()
  @dialyzer {:no_opaque, batch_insert: 1}
  def batch_insert([]), do: :noop

  def batch_insert([%Analyzer.Result{} | _] = files) do
    Multi.new()
    |> Multi.run(:settings, fn _repo, _multi ->
      {:ok, Settings.get()}
    end)
    |> Multi.run(:changed_files, &find_changed_files(&1, files, &2))
    |> Multi.run(:files, &maybe_create_files(&1, files, &2))
    |> Multi.run(:artists, &maybe_create_artists/2)
    |> Multi.run(:albums, &maybe_create_albums/2)
    |> Multi.run(:tracks, &maybe_create_tracks/2)
    |> Multi.run(:album_years, &update_album_release_years/2)
    |> Multi.run(:counts, &update_counts/2)
    |> Multi.run(:invalidated_artworks, &invalidate_changed_artworks/2)
    |> Repo.transact()
  end

  def broadcast(:batch, results) do
    changes =
      Map.new([:artists, :albums], fn key ->
        ids = Enum.map(results[key], & &1.id) ++ results.counts[key]
        {key, Enum.uniq(ids)}
      end)

    broadcast(MusicBox.PubSub, "library:sync", "processed", changes)
  end

  def broadcast(:deleted, %DateTime{} = before) do
    results =
      DeletionLog
      |> where([d], d.deleted_at >= ^before)
      |> Repo.all()

    # Pubsub expect pluralized keys, deletion log is singular
    deleted =
      Enum.map(results, fn row ->
        %{entityType: row.entity_type, entityId: row.entity_id}
      end)

    if deleted != [] do
      broadcast(MusicBox.PubSub, "library:sync", "deleted", %{
        deletions: deleted
      })
    end
  end

  def broadcast(:completed) do
    broadcast(MusicBox.PubSub, "library:sync", "completed", %{})
  end

  @spec find_unchanged_paths([Storage.file_entry()]) :: [String.t()]
  def find_unchanged_paths([]), do: []

  def find_unchanged_paths(entries) do
    paths = Enum.map(entries, & &1.path)
    lookup = Map.new(entries, &{&1.path, &1})

    from(f in File, where: f.path in ^paths)
    |> Repo.all()
    |> Enum.filter(fn old_file ->
      new_file = Map.get(lookup, old_file.path)
      unchanged? = true

      unchanged? =
        if new_file.mtime == old_file.last_modified_at,
          do: unchanged?,
          else: false

      unchanged? =
        if new_file.size == old_file.size,
          do: unchanged?,
          else: false

      unchanged?
    end)
    |> Enum.map(& &1.path)
  end

  defp maybe_create_files(repo, files, %{changed_files: changed_files}) do
    file_fields = File.__schema__(:fields) -- [:metadata]

    entries =
      files
      |> Enum.map(fn %{metadata: %{} = metadata} = entry ->
        metadata =
          %FileMetadata{}
          |> FileMetadata.changeset(Map.from_struct(metadata))
          |> Ecto.Changeset.apply_changes()

        entry
        |> Map.take(file_fields)
        |> Map.put(:metadata, metadata)
      end)
      |> Enum.map(&add_timestamps(&1, [:last_scanned_at, :content_changed_at]))

    mark_content_changed(repo, changed_files.file_ids)

    {_num, files} =
      repo.insert_all(File, entries,
        returning: true,
        conflict_target: [:path],
        on_conflict: {:replace_all_except, [:id, :inserted_at, :loudness, :content_changed_at]}
      )

    {:ok, files}
  end

  # This returns new or modified files since last scan, and it also attempts to
  # return previously known album ids when possible (as a metadata change could
  # have resulted in it being associated with a different album now).
  defp find_changed_files(repo, files, _results) do
    lookup = Map.new(files, &{&1.path, {&1.size, &1.last_modified_at}})
    paths = Map.keys(lookup)

    known_files =
      from(f in File,
        left_join: t in assoc(f, :track),
        where: f.path in ^paths,
        select: %{
          id: f.id,
          path: f.path,
          size: f.size,
          mtime: f.last_modified_at,
          album_id: t.album_id
        }
      )
      |> repo.all()

    changed = Enum.reject(known_files, &(Map.get(lookup, &1.path) == {&1.size, &1.mtime}))
    new_paths = paths -- Enum.map(known_files, & &1.path)

    {:ok,
     %{
       file_ids: Enum.map(changed, & &1.id),
       paths: Enum.map(changed, & &1.path) ++ new_paths,
       previous_album_ids: Enum.map(changed, & &1.album_id)
     }}
  end

  # Keeps the counts up to date while scanning and finding new entries, any
  # deletions will be dealt with in the cleanup worker.
  defp update_counts(_repo, %{albums: albums, changed_files: changed_files}) do
    album_ids =
      Enum.map(albums, & &1.id) ++ Enum.reject(changed_files.previous_album_ids, &is_nil/1)

    artist_ids = Enum.map(albums, & &1.artist_id)

    {:ok,
     %{
       artists: Counters.update(Artist, :album_count, Album, :artist_id, Enum.uniq(artist_ids)),
       albums: Counters.update(Album, :track_count, Track, :album_id, Enum.uniq(album_ids))
     }}
  end

  defp mark_content_changed(repo, file_ids) do
    from(f in File, where: f.id in ^file_ids)
    |> repo.update_all(set: [content_changed_at: DateTime.utc_now(:second)])
  end

  defp invalidate_changed_artworks(repo, %{changed_files: changed_files}) do
    current_album_ids =
      from(t in Track,
        join: f in assoc(t, :file),
        where: f.path in ^changed_files.paths,
        select: t.album_id
      )
      |> repo.all()

    invalidate_artworks(repo, changed_files.previous_album_ids ++ current_album_ids)
  end

  @doc """
  Compares the cover files found in a complete walk of the music path with the
  best cover file each album directory had during its last fetch attempt. Albums
  of which a cover file was added, changed or removed are invalidated.
  """
  @spec invalidate_cover_files([Storage.file_entry()]) :: {:ok, non_neg_integer()}
  def invalidate_cover_files(cover_files) do
    cover_files_by_dir = Enum.group_by(cover_files, &Path.dirname(&1.path))

    # Same as the fetcher, the cover file is found across all album directories.
    current_cover = fn dirs ->
      dirs |> Enum.flat_map(&Map.get(cover_files_by_dir, &1, [])) |> CoverFile.find()
    end

    # Find all album ids that have artwork in one of these directories
    album_ids =
      from(aw in Artwork, where: not is_nil(aw.dirs), select: {aw.album_id, aw.dirs, aw.cover})
      |> Repo.all()
      |> Enum.reject(fn {_album_id, dirs, cover} -> current_cover.(dirs) == cover end)
      |> Enum.map(fn {album_id, _dirs, _cover} -> album_id end)

    invalidate_artworks(Repo, album_ids)
  end

  defp invalidate_artworks(repo, album_ids) do
    now = DateTime.utc_now(:second)

    album_ids
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.chunk_every(1_000)
    |> Enum.reduce({:ok, 0}, fn ids, {:ok, count} ->
      {updated, _} =
        from(aw in Artwork, where: aw.album_id in ^ids)
        |> repo.update_all(set: [invalidated_at: now])

      {:ok, count + updated}
    end)
  end

  defp maybe_create_artists(repo, %{files: files, settings: settings}) do
    artist_names =
      files
      |> Enum.flat_map(&[&1.metadata.album_artist, &1.metadata.artist])
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq_by(&String.downcase/1)

    entries =
      artist_names
      |> Enum.map(fn artist_name ->
        %{
          name: artist_name,
          sort_name: Utils.sort_name(artist_name, strip_prefixes: settings.strip_sort_prefixes),
          slug: Utils.slugify(artist_name)
        }
      end)
      |> Enum.map(&add_timestamps/1)

    {_num, artists} =
      repo.insert_all(Artist, entries,
        returning: true,
        conflict_target: [:slug],
        # Counts are maintained separately, keep them.
        on_conflict: {:replace_all_except, [:id, :inserted_at, :album_count]}
      )

    {:ok, artists}
  end

  defp maybe_create_albums(repo, %{files: files, artists: artists, settings: settings}) do
    linked_file_artists =
      files
      |> Enum.reject(&is_nil(&1.metadata.album_artist))
      |> Enum.map(fn file ->
        match_artist = String.downcase(file.metadata.album_artist)
        album_artist = Enum.find(artists, &(String.downcase(&1.name) == match_artist))

        %{
          file: file,
          artist: album_artist,
          is_unknown: is_nil(file.metadata.album)
        }
      end)
      |> Enum.reject(&is_nil(&1.artist))

    artist_albums =
      linked_file_artists
      |> Enum.group_by(fn %{is_unknown: u, artist: a, file: %{metadata: m}} ->
        {u, a, m.album || ""}
      end)
      |> Enum.map(fn {_key, [first | _] = group} ->
        years = Enum.map(group, & &1.file.metadata.release_year)
        Map.put(first, :release_year, find_distinct_release_year(years))
      end)

    entries =
      artist_albums
      |> Enum.map(fn %{file: file, artist: artist, is_unknown: is_unknown} = entry ->
        album_name = file.metadata.album || "Unknown Album"

        # For unknown albums we will add a hex prefix, e.g. "b33f-unknown" where
        # the hex is just a substring of the artist names. As album slugs are
        # unique by artist_id and we want to allow a "real" Unknown album option
        slug_name =
          if album = file.metadata.album,
            do: Utils.slugify(album),
            else: [Utils.short_hex(artist.name, 2), "unknown"] |> Enum.join("-")

        %{
          artist_id: artist.id,
          name: album_name,
          slug: slug_name,
          sort_name: Utils.sort_name(album_name, strip_prefixes: settings.strip_sort_prefixes),
          compilation: file.metadata.compilation,
          release_year: entry.release_year,
          is_unknown: is_unknown
        }
      end)
      |> Enum.map(&add_timestamps/1)

    {_num, albums} =
      repo.insert_all(Album, entries,
        returning: true,
        conflict_target: [:artist_id, :slug],
        # Counts are maintained separately, keep them.
        on_conflict: {:replace_all_except, [:id, :inserted_at, :track_count]}
      )

    {:ok, albums}
  end

  defp maybe_create_tracks(repo, %{
         files: files,
         artists: artists,
         albums: albums
       }) do
    linked_file_albums =
      files
      |> Enum.map(fn %{metadata: metadata} = file ->
        artist =
          if is_binary(metadata.artist) do
            match_artist = String.downcase(metadata.artist)
            Enum.find(artists, &(String.downcase(&1.name) == match_artist))
          end

        album =
          cond do
            is_binary(metadata.album_artist) and is_binary(metadata.album) ->
              match_artist = String.downcase(metadata.album_artist)
              match_album = String.downcase(metadata.album)
              album_artist = Enum.find(artists, &(String.downcase(&1.name) == match_artist))

              if album_artist do
                albums
                |> Enum.filter(&(&1.artist_id == album_artist.id))
                |> Enum.reject(& &1.is_unknown)
                |> Enum.find(&(String.downcase(&1.name) == match_album))
              end

            is_binary(metadata.album_artist) ->
              match_artist = String.downcase(metadata.album_artist)
              album_artist = Enum.find(artists, &(String.downcase(&1.name) == match_artist))

              # credo:disable-for-next-line Credo.Check.Refactor.Nesting
              if album_artist do
                albums
                |> Enum.filter(&(&1.artist_id == album_artist.id and &1.is_unknown))
                |> List.first()
              end

            true ->
              nil
          end

        %{
          file: file,
          album: album,
          artist: artist
        }
      end)

    entries =
      linked_file_albums
      |> Enum.map(fn %{file: file, album: album, artist: artist} ->
        title =
          case file.metadata.title do
            nil -> Path.basename(file.path)
            title -> title
          end

        %{
          artist_id: artist && artist.id,
          album_id: album && album.id,
          file_id: file.id,
          duration: file.metadata.duration,
          number: file.metadata.track,
          disc: file.metadata.disc,
          name: title,
          slug: Utils.slugify(title)
        }
      end)
      |> Enum.map(&add_timestamps/1)

    {_num, tracks} =
      repo.insert_all(Track, entries,
        returning: true,
        conflict_target: [:file_id],
        # Plays are kept track of separately, keep them.
        on_conflict: {:replace_all_except, [:id, :inserted_at, :play_count, :last_played_at]}
      )

    {:ok, tracks}
  end

  # This function tries to set the album release year if it is missing despite
  # one of the other tracks does have the metadata and they were just batched
  # differently so it was not included in album creation. It also clears the
  # year again if tracks across batches have conflicting years for some reason.
  defp update_album_release_years(repo, %{albums: albums}) do
    album_ids = Enum.map(albums, & &1.id)

    years_by_album =
      from(t in Track,
        join: f in assoc(t, :file),
        where: t.album_id in ^album_ids,
        distinct: true,
        select: {t.album_id, f.metadata["release_year"]}
      )
      |> repo.all()
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    # Only write albums where the year differs from what the upsert just set
    albums
    |> Enum.map(&{&1, find_distinct_release_year(Map.get(years_by_album, &1.id, []))})
    |> Enum.reject(fn {album, year} -> album.release_year == year end)
    |> Enum.group_by(&elem(&1, 1), &elem(&1, 0).id)
    |> Enum.each(fn {year, ids} ->
      from(al in Album, where: al.id in ^ids)
      |> repo.update_all(set: [release_year: year])
    end)

    {:ok, years_by_album}
  end

  # Use the year if all tracks that have one agree, otherwise leave it unset
  # rather than guessing between conflicting values.
  defp find_distinct_release_year(years) do
    case years |> Enum.reject(&is_nil/1) |> Enum.uniq() do
      [year] -> year
      _none_or_conflicting -> nil
    end
  end

  @doc "Returns the ids of files that no longer exist in the music path."
  @spec find_missing_files(Keyword.t()) :: [Ecto.UUID.t()]
  def find_missing_files(opts \\ []), do: missing_file_ids(opts)

  # Checks a batch of files at a time, continuing after the last checked id.
  defp missing_file_ids(opts, last_id \\ nil) do
    batch_size = Keyword.get(opts, :batch_size, 500)

    case files_after(last_id, batch_size) do
      [] ->
        []

      files ->
        {last_id, _path} = List.last(files)
        missing = files |> Enum.chunk_every(50) |> Enum.flat_map(&verify_files/1)
        Enum.map(missing, &elem(&1, 0)) ++ missing_file_ids(opts, last_id)
    end
  end

  # NOTE: Repo.stream is useless with SQLite so let's do our own batching, by id
  # rather than offset so changes to the table can't make it skip files.
  defp files_after(last_id, limit) do
    query = from(f in File, select: {f.id, f.path}, order_by: f.id, limit: ^limit)
    query = if last_id, do: where(query, [f], f.id > ^last_id), else: query
    Repo.all(query)
  end

  @spec delete_files([Ecto.UUID.t()]) :: {:ok, non_neg_integer()}
  def delete_files(file_ids) do
    {deleted, errored} =
      file_ids
      |> Enum.chunk_every(50)
      |> Enum.reduce({0, 0}, &delete_files_reducer(&1, &2))

    if errored > 0, do: Logger.warning("failed to delete #{errored} files")

    # The results of deletions are not important, they are marked as deleted
    # through SQLite triggers.
    {:ok, deleted}
  end

  defp delete_files_reducer(file_ids, {deleted_acc, error_acc}) do
    # Get the album ids for any deleted files so we can invalidate their artwork
    album_ids =
      from(t in Track, where: t.file_id in ^file_ids, select: t.album_id)
      |> Repo.all()

    File
    |> where([f], f.id in ^file_ids)
    |> Repo.delete_all()
    |> case do
      {count, _} ->
        invalidate_artworks(Repo, album_ids)
        {deleted_acc + count, error_acc}

      _ ->
        {deleted_acc, error_acc + length(file_ids)}
    end
  end

  defp verify_files(files) do
    missing_files =
      files
      |> Enum.map(fn {_id, path} -> path end)
      |> Storage.find_missing_files()

    files
    |> Enum.flat_map(fn {id, path} ->
      if path in missing_files do
        [{id, path, :missing}]
      else
        []
      end
    end)
  end

  defp add_timestamps(entry, additional_fields \\ []) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    date_fields = [:inserted_at, :updated_at] ++ additional_fields

    Enum.reduce(date_fields, entry, fn field, entry ->
      Map.put(entry, field, now)
    end)
  end
end
