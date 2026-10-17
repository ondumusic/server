# credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
defmodule Ondu.FileScanner.Operations do
  @moduledoc false

  import Phoenix.Channel.Server, only: [broadcast: 4]

  alias Ecto.Multi
  alias Ondu.Albums
  alias Ondu.Albums.{Album, Artwork, CoverFile}
  alias Ondu.Artists.Artist
  alias Ondu.Counters
  alias Ondu.DeletionLog
  alias Ondu.Files.{File, FileMetadata}
  alias Ondu.FileScanner.{Analyzer, Replacements, Utils}
  alias Ondu.FileScanner.Replacements.Candidate
  alias Ondu.Repo
  alias Ondu.Settings
  alias Ondu.Storage
  alias Ondu.Tracks.Track

  import Ecto.Query

  require Logger

  # The missing file ids could be files that have moved to one of the new paths
  # in this batch. If they are we can handle them as a move instead of delete.
  @spec batch_insert([Analyzer.Result.t()], MapSet.t(Ecto.UUID.t())) ::
          :noop
          | {:ok,
             %{
               artists: [Artist],
               albums: [Album],
               tracks: [Track],
               files: [File],
               moved_files: [Ecto.UUID.t()],
               possible_replacements: [Analyzer.Result.t()],
               counts: %{artists: [Ecto.UUID.t()], albums: [Ecto.UUID.t()]}
             }}
          | Ecto.Multi.failure()
  @dialyzer {:no_opaque, batch_insert: 2}
  def batch_insert(files, missing_file_ids \\ MapSet.new())
  def batch_insert([], _missing_file_ids), do: :noop

  def batch_insert([%Analyzer.Result{} | _] = files, missing_file_ids) do
    Multi.new()
    |> Multi.run(:settings, fn _repo, _multi ->
      {:ok, Settings.get()}
    end)
    |> Multi.run(:moved_files, &move_files(&1, files, missing_file_ids, &2))
    |> Multi.run(
      :possible_replacements,
      &find_possible_replacements(&1, files, missing_file_ids, &2)
    )
    |> Multi.run(:changed_files, &find_changed_files(&1, files -- &2.possible_replacements, &2))
    |> Multi.run(:files, &maybe_create_files(&1, files -- &2.possible_replacements, &2))
    |> Multi.run(:artists, &maybe_create_artists/2)
    |> Multi.run(:albums, &maybe_create_albums/2)
    |> Multi.run(:tracks, &maybe_create_tracks/2)
    |> Multi.run(:previous_albums, &mark_previous_albums/2)
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

    broadcast(Ondu.PubSub, "library:sync", "processed", changes)
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
      broadcast(Ondu.PubSub, "library:sync", "deleted", %{
        deletions: deleted
      })
    end
  end

  def broadcast(:completed) do
    broadcast(Ondu.PubSub, "library:sync", "completed", %{})
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

  # A new path with the same size and tags as a missing file is that file moved
  # (or renamed), its path is updated so it keeps its id and with it everything
  # linked to its track (plays, playlist items, ...). Several new paths for the
  # same tags and size are copies of the same file, so they are paired with the
  # missing files in any order. Returns the ids of the moved files.
  defp move_files(repo, files, missing_file_ids, _results) do
    paths = Enum.map(files, & &1.path)

    # Gets all known paths from the database
    known_paths =
      from(f in File, where: f.path in ^paths, select: f.path)
      |> repo.all()
      |> MapSet.new()

    # Reject any `files` that are already known.
    new_files = Enum.reject(files, &MapSet.member?(known_paths, &1.path))

    # Then create a list of unique sizes which will be one of the ways we'll
    # try to detect moved files.
    sizes = new_files |> Enum.map(& &1.size) |> Enum.uniq()

    # Now we will query any files based on identical file size, and then for all
    # that match the `missing_file_ids` we will group them by metadata.
    missing_files =
      from(f in File, where: f.size in ^sizes, order_by: f.path)
      |> repo.all()
      |> Enum.filter(&MapSet.member?(missing_file_ids, &1.id))
      |> Enum.group_by(&{&1.size, comparable_metadata(&1.metadata)})

    # Now group our newly found files by metadata as well and compare them with
    # our `missing_files`. Any matches will be considered a move and updated
    # immediately and touch moved tracks to indicate they have been updated.
    moved =
      new_files
      |> Enum.sort_by(& &1.path)
      |> Enum.group_by(&{&1.size, comparable_metadata(&1.metadata)})
      |> Enum.flat_map(fn {key, files} -> Enum.zip(Map.get(missing_files, key, []), files) end)

    # When we update the file `path` on the existing record to the new path the
    # rest of the scanning pipeline will see it as an unchanged file instead of
    # a new file.
    for {missing_file, file} <- moved do
      from(f in File, where: f.id == ^missing_file.id)
      |> repo.update_all(set: [path: file.path, last_modified_at: file.last_modified_at])

      Logger.info("Moved #{missing_file.path} to #{file.path}")
    end

    file_ids = Enum.map(moved, fn {missing_file, _file} -> missing_file.id end)

    # Bump the updated_at so sync will expose the updated relativeFilePath, and
    # also mark the artwork as invalidated so it will refresh this too if needed.
    touch_moved_tracks(repo, file_ids)
    {:ok, file_ids}
  end

  # Compares missing files with any newly found files to determine whether or
  # not this file has a possible candidate to replace the missing track. This
  # is a process that happens after all batches have been inserted, so we
  # collect the possible replacement to process later.
  defp find_possible_replacements(repo, files, missing_file_ids, %{moved_files: moved_file_ids}) do
    missing_file_ids = MapSet.difference(missing_file_ids, MapSet.new(moved_file_ids))

    # No missing files? Then we have nothing to do.
    if MapSet.size(missing_file_ids) == 0 do
      {:ok, []}
    else
      file_paths = Enum.map(files, & &1.path)

      known_paths =
        from(f in File, where: f.path in ^file_paths, select: f.path)
        |> repo.all()
        |> MapSet.new()

      new_files = Enum.reject(files, &MapSet.member?(known_paths, &1.path))
      new_candidates = Enum.map(new_files, &to_candidate/1)
      missing = find_missing_candidates(repo, new_candidates, missing_file_ids)

      possible_replacements =
        Enum.filter(new_files, fn file ->
          Enum.any?(missing, &Replacements.replaced?(&1, to_candidate(file)))
        end)

      {:ok, possible_replacements}
    end
  end

  @doc """
  This will match possible replacements with missing files. For any eligible
  replacements it will replace the path of the file entry in the database
  instead of creating new ones.

  Returns the ids of the replaced files.
  """
  @spec replace_files([Analyzer.Result.t()], MapSet.t(Ecto.UUID.t())) :: {:ok, [Ecto.UUID.t()]}
  def replace_files([], _missing_file_ids), do: {:ok, []}

  def replace_files(files, missing_file_ids) do
    new = Enum.map(files, &to_candidate/1)
    missing = find_missing_candidates(Repo, new, missing_file_ids)
    replaced = Replacements.match(missing, new)

    for {old, new} <- replaced do
      from(f in File, where: f.id == ^old.file_id)
      |> Repo.update_all(set: [path: new.path])

      Logger.info("Replaced #{old.path} with #{new.path}")
    end

    {:ok, Enum.map(replaced, fn {old, _new} -> old.file_id end)}
  end

  # Attempt to load existing Track records from the missing files based on
  # the duration (with margin). This might look weird but don't worry this
  # is just to select likely candidates, the actual comparison happens later.
  defp find_missing_candidates(repo, candidates, missing_file_ids) do
    max_difference = Replacements.max_duration_difference()
    durations = candidates |> Enum.map(& &1.duration) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    # Build a dynamic lookup based on all the file durations
    similar_duration =
      Enum.reduce(durations, dynamic(false), fn duration, conditions ->
        min = duration - max_difference
        max = duration + max_difference
        dynamic([t], ^conditions or (t.duration >= ^min and t.duration <= ^max))
      end)

    from(t in Track,
      join: f in assoc(t, :file),
      where: ^similar_duration,
      select: %{
        file_id: f.id,
        path: f.path,
        duration: t.duration,
        artist: f.metadata["artist"],
        album: f.metadata["album"],
        title: f.metadata["title"],
        disc: f.metadata["disc"],
        track: f.metadata["track"]
      }
    )
    |> repo.all()
    |> Enum.filter(&MapSet.member?(missing_file_ids, &1.file_id))
    |> Enum.map(&struct!(Candidate, &1))
  end

  defp to_candidate(%Analyzer.Result{path: path, metadata: metadata}) do
    %Candidate{
      path: path,
      duration: metadata.duration,
      artist: metadata.artist,
      album: metadata.album,
      title: metadata.title,
      disc: metadata.disc,
      track: metadata.track
    }
  end

  # Returns the file metadata to be used in `move_files` to compare new files
  # with old ones and detect whether or not this was a moved file.
  defp comparable_metadata(metadata) do
    %FileMetadata{}
    |> FileMetadata.changeset(Map.from_struct(metadata))
    |> Ecto.Changeset.apply_changes()
  end

  # The path of their tracks changed, and their album directory might have.
  defp touch_moved_tracks(_repo, []), do: :ok

  defp touch_moved_tracks(repo, file_ids) do
    {_count, album_ids} =
      from(t in Track, where: t.file_id in ^file_ids, select: t.album_id)
      |> repo.update_all(set: [updated_at: DateTime.utc_now(:second)])

    Albums.invalidate_artworks(Enum.reject(album_ids, &is_nil/1))
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

    Albums.invalidate_artworks(changed_files.previous_album_ids ++ current_album_ids)
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

    Albums.invalidate_artworks(album_ids)
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
        Map.put(first, :release_year, find_release_year(years))
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

  # Changed files could have a different album now, for example when the album
  # name was modified (e.g. a typo was fixed). Their tracks will record the
  # original album id so we can later correct this.
  defp mark_previous_albums(repo, %{changed_files: changed_files}) do
    previous_albums =
      changed_files.file_ids
      |> Enum.zip(changed_files.previous_album_ids)
      |> Enum.reject(fn {_file_id, album_id} -> is_nil(album_id) end)
      |> Enum.group_by(
        fn {_file_id, album_id} -> album_id end,
        fn {file_id, _album_id} -> file_id end
      )

    for {album_id, file_ids} <- previous_albums do
      from(t in Track, where: t.file_id in ^file_ids and t.album_id != ^album_id)
      |> repo.update_all(set: [previous_album_id: album_id])
    end

    {:ok, previous_albums}
  end

  @doc """
  This will update the existing album record with the new details, and point the
  tracks back to the original album, and delete the newly inserted album record.

  This is done to preserve all existing data (artwork, annotations, etc.) we
  have for albums instead, and to avoid having a scenario where fixing a typo
  in the album name results in it appearing as a newly added album.
  """
  @spec keep_renamed_albums() :: {:ok, %{albums: [Ecto.UUID.t()], artists: [Ecto.UUID.t()]}}
  def keep_renamed_albums do
    Repo.transact(fn ->
      renamed = find_renamed_albums()

      renamed_albums =
        Enum.map(renamed, fn {previous_album_id, album_id} ->
          keep_renamed_album(previous_album_id, album_id)
        end)

      # When the album artist was also renamed, we'll apply the same trick
      # to the artists.
      renamed_artists = find_renamed_artists(renamed_albums)

      for {previous_artist_id, artist_id} <- renamed_artists do
        keep_renamed_artist(previous_artist_id, artist_id)
      end

      # Now every renamed album should have been preserved, so we can clear
      # the previous_album_ids on the tracks.
      from(t in Track, where: not is_nil(t.previous_album_id))
      |> Repo.update_all(set: [previous_album_id: nil])

      # We'll invalidate artwork so the artwork fetcher will check if it needs
      # to replace the current artwork.
      album_ids = Enum.map(renamed, fn {previous_album_id, _album_id} -> previous_album_id end)
      Albums.invalidate_artworks(album_ids)

      artist_ids =
        Enum.map(renamed_artists, fn {previous_artist_id, _artist_id} -> previous_artist_id end)

      if album_ids != [] do
        broadcast(Ondu.PubSub, "library:sync", "processed", %{
          artists: artist_ids,
          albums: album_ids
        })
      end

      {:ok, %{albums: album_ids, artists: artist_ids}}
    end)
  end

  defp find_renamed_albums do
    # Get all albums marked as possible replacements
    marked =
      from(t in Track,
        where: not is_nil(t.previous_album_id),
        group_by: [t.album_id, t.previous_album_id],
        select: {t.album_id, t.previous_album_id, count(t.id)}
      )
      |> Repo.all()

    # Combine all album ids, new and old, into one list
    album_ids =
      Enum.flat_map(marked, fn {album_id, previous_album_id, _count} ->
        [album_id, previous_album_id]
      end)

    # Get the track count for every album, new and old
    # we do this to make sure all tracks can be moved to the
    # original album record.
    track_counts =
      from(t in Track,
        where: t.album_id in ^album_ids,
        group_by: t.album_id,
        select: {t.album_id, count(t.id)}
      )
      |> Repo.all()
      |> Map.new()

    marked
    |> Enum.filter(fn {album_id, previous_album_id, count} ->
      # We only want to revert to the previous_album_id when all its tracks have
      # moved to the new album, and the previous one has no tracks right now.
      all_moved? = Map.get(track_counts, album_id) == count
      previous_unused? = not Map.has_key?(track_counts, previous_album_id)
      all_moved? and previous_unused?
    end)
    |> Enum.group_by(fn {_album_id, previous_album_id, _count} -> previous_album_id end)
    |> Enum.filter(fn {_previous_album_id, albums} ->
      # We also want to ensure the tracks are not split over multiple new albums,
      # otherwise we should not revert them to the old album record.
      length(albums) == 1
    end)
    |> Enum.map(fn {previous_album_id, [{album_id, _previous_album_id, _count}]} ->
      {previous_album_id, album_id}
    end)
  end

  # This reverts the tracks back to the previous_album_id, as well as update
  # the album record with all the new details. The newly inserted album is also
  # deleted as it should not have any tracks anymore.
  defp keep_renamed_album(previous_album_id, album_id) do
    album = Repo.get!(Album, album_id)
    previous_album = Repo.get!(Album, previous_album_id)
    now = DateTime.utc_now(:second)

    from(t in Track, where: t.album_id == ^album_id)
    |> Repo.update_all(set: [album_id: previous_album_id, updated_at: now])

    Repo.delete!(album)

    from(al in Album, where: al.id == ^previous_album_id)
    |> Repo.update_all(
      set: [
        artist_id: album.artist_id,
        name: album.name,
        slug: album.slug,
        sort_name: album.sort_name,
        compilation: album.compilation,
        release_year: album.release_year,
        is_unknown: album.is_unknown,
        track_count: album.track_count,
        updated_at: now
      ]
    )

    Logger.info("Renamed album #{previous_album.name} to #{album.name}")

    {previous_album.artist_id, album.artist_id, previous_album_id}
  end

  # This takes the list of `keep_renamed_album/2` results, which contains the
  # previous album artist id, the new album artist id, and the previous
  # album id. Similar to albums, it will return artist that have been replaced
  # and no longer have any associated albums or tracks.
  defp find_renamed_artists(renamed_albums) do
    renamed_albums
    |> Enum.reject(fn {previous_artist_id, artist_id, _album_id} ->
      previous_artist_id == artist_id
    end)
    |> Enum.group_by(
      fn {previous_artist_id, artist_id, _album_id} -> {previous_artist_id, artist_id} end,
      fn {_previous_artist_id, _artist_id, album_id} -> album_id end
    )
    |> Enum.filter(fn {{previous_artist_id, artist_id}, album_ids} ->
      renamed_artist?(previous_artist_id, artist_id, album_ids)
    end)
    |> Enum.group_by(fn {{previous_artist_id, _artist_id}, _album_ids} -> previous_artist_id end)
    |> Enum.filter(fn {_previous_artist_id, artists} -> length(artists) == 1 end)
    |> Enum.map(fn {previous_artist_id, [{{_previous_artist_id, artist_id}, _album_ids}]} ->
      {previous_artist_id, artist_id}
    end)
  end

  defp renamed_artist?(previous_artist_id, artist_id, album_ids) do
    previous_used? =
      Repo.exists?(from(al in Album, where: al.artist_id == ^previous_artist_id)) or
        Repo.exists?(from(t in Track, where: t.artist_id == ^previous_artist_id))

    # The artist should only have the renamed albums, nothing else
    other_albums? =
      from(al in Album, where: al.artist_id == ^artist_id and al.id not in ^album_ids)
      |> Repo.exists?()

    # Same with tracks, the artist should not have any associated tracks anymore
    # that are not also related to one of the renamed albums.
    other_tracks? =
      from(t in Track,
        where: t.artist_id == ^artist_id,
        where: is_nil(t.album_id) or t.album_id not in ^album_ids
      )
      |> Repo.exists?()

    not previous_used? and not other_albums? and not other_tracks?
  end

  # Same as albums, the albums and tracks are reverted back to the previous
  # artist, which also gets the details of the new artist. It will then also
  # delete the newly inserted Artist record that should no longer have any
  # albums or tracks at this stage.
  defp keep_renamed_artist(previous_artist_id, artist_id) do
    artist = Repo.get!(Artist, artist_id)
    previous_artist = Repo.get!(Artist, previous_artist_id)
    now = DateTime.utc_now(:second)

    from(al in Album, where: al.artist_id == ^artist_id)
    |> Repo.update_all(set: [artist_id: previous_artist_id, updated_at: now])

    from(t in Track, where: t.artist_id == ^artist_id)
    |> Repo.update_all(set: [artist_id: previous_artist_id, updated_at: now])

    Repo.delete!(artist)

    from(a in Artist, where: a.id == ^previous_artist_id)
    |> Repo.update_all(
      set: [
        name: artist.name,
        slug: artist.slug,
        sort_name: artist.sort_name,
        album_count: artist.album_count,
        updated_at: now
      ]
    )

    Logger.info("Renamed artist #{previous_artist.name} to #{artist.name}")
  end

  # This sets the release years for the given albums by analysing the track tags
  # to figure out the release year for each album, and then update it.
  defp update_album_release_years(repo, %{albums: albums}) do
    album_ids = Enum.map(albums, & &1.id)

    years_by_album =
      from(t in Track,
        join: f in assoc(t, :file),
        where: t.album_id in ^album_ids,
        select: {t.album_id, f.metadata["release_year"]}
      )
      |> repo.all()
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    # Only write albums where the year differs from what the upsert just set
    albums
    |> Enum.map(&{&1, find_release_year(Map.get(years_by_album, &1.id, []))})
    |> Enum.reject(fn {album, year} -> album.release_year == year end)
    |> Enum.group_by(&elem(&1, 1), &elem(&1, 0).id)
    |> Enum.each(fn {year, ids} ->
      from(al in Album, where: al.id in ^ids)
      |> repo.update_all(set: [release_year: year])
    end)

    {:ok, years_by_album}
  end

  # This find the most common release year in a list of years (which come from
  # album tracks). For example iTunes sometimes tags a single with the original
  # release year and then others for the album release year, which caused a
  # conflict. Now we use the most common year, and if it's a tie we use the
  # newest year, as that seems more likely to be the correct one.
  defp find_release_year(years) do
    years
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
    |> Enum.max_by(fn {year, count} -> {count, year} end, fn -> {nil, 0} end)
    |> elem(0)
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
        Albums.invalidate_artworks(album_ids)
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
