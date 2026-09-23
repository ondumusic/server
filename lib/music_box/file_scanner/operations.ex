# credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
defmodule MusicBox.FileScanner.Operations do
  @moduledoc false

  import Phoenix.Channel.Server, only: [broadcast: 4]

  alias Ecto.Multi
  alias MusicBox.Albums.Album
  alias MusicBox.Artists.Artist
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
               files: [File]
             }}
          | Ecto.Multi.failure()
  @dialyzer {:no_opaque, batch_insert: 1}
  def batch_insert([]), do: :noop

  def batch_insert([%Analyzer.Result{} | _] = files) do
    Multi.new()
    |> Multi.run(:settings, fn _repo, _multi ->
      {:ok, Settings.get()}
    end)
    |> Multi.run(:files, &maybe_create_files(&1, files, &2))
    |> Multi.run(:artists, &maybe_create_artists/2)
    |> Multi.run(:albums, &maybe_create_albums/2)
    |> Multi.run(:tracks, &maybe_create_tracks/2)
    |> Multi.run(:album_years, &update_album_release_years/2)
    |> Repo.transact()
  end

  def broadcast(:batch, results) do
    changes =
      results
      |> Map.take([:artists, :albums])
      |> Enum.map(fn {key, items} ->
        {key, Enum.map(items, & &1.id)}
      end)
      |> Map.new()

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

  defp maybe_create_files(repo, files, _results) do
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
      |> Enum.map(&add_timestamps(&1, [:last_scanned_at]))

    {_num, files} =
      repo.insert_all(File, entries,
        returning: true,
        conflict_target: [:path],
        on_conflict: {:replace_all_except, [:id, :inserted_at]}
      )

    {:ok, files}
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
        on_conflict: {:replace_all_except, [:id, :inserted_at]}
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
        on_conflict: {:replace_all_except, [:id, :inserted_at]}
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
        on_conflict: {:replace_all_except, [:id, :inserted_at]}
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

  def find_deleted_files(opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, 500)
    base_query = from(f in File, select: {f.id, f.path}, order_by: [asc: :updated_at])
    file_count = Repo.aggregate(base_query, :count)

    # NOTE: Repo.stream is useless with SQLite so let's do our own batching.
    for page <- 0..div(file_count, batch_size) do
      base_query
      |> offset(^(page * batch_size))
      |> limit(^batch_size)
      |> Repo.all()
      |> Stream.chunk_every(50)
      |> Stream.flat_map(&verify_files/1)
      |> Stream.filter(fn {_, _, status} -> status == :missing end)
      |> Stream.map(&elem(&1, 0))
      |> Stream.chunk_every(50)
      |> Enum.reduce({0, 0}, &delete_files_reducer(&1, &2))
      |> case do
        {_deleted, 0} ->
          :noop

        {_deleted, errored} ->
          Logger.warning("failed to delete #{errored} files")
      end
    end

    # The results of deletions are not important, they are marked as deleted
    # through SQLite triggers.
    :ok
  end

  defp delete_files_reducer(file_ids, {deleted_acc, error_acc}) do
    File
    |> where([f], f.id in ^file_ids)
    |> Repo.delete_all()
    |> case do
      {count, _} ->
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
