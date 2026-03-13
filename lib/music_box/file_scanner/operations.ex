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
      |> Enum.group_by(& &1.entity_type, & &1.entity_id)

    # Pubsub expect pluralized keys, deletion log is singular
    deleted = %{
      files: Map.get(results, :file, []),
      tracks: Map.get(results, :track, []),
      artists: Map.get(results, :artist, []),
      albums: Map.get(results, :album, [])
    }

    broadcast(MusicBox.PubSub, "library:sync", "deleted", deleted)
  end

  def broadcast(:completed) do
    broadcast(MusicBox.PubSub, "library:sync", "completed", %{})
  end

  def find_existing_paths([]), do: []

  def find_existing_paths(paths) do
    from(f in File, where: f.path in ^paths, select: f.path)
    |> Repo.all()
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
      |> Enum.uniq_by(fn %{is_unknown: u, artist: a, file: %{metadata: m}} ->
        {u, a, m.album || ""}
      end)

    entries =
      artist_albums
      |> Enum.map(fn %{file: file, artist: artist, is_unknown: is_unknown} ->
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
          release_year: file.metadata.release_year,
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

  def find_deleted_files do
    Repo.transact(
      fn repo ->
        from(f in File, select: {f.id, f.path})
        |> repo.stream()
        |> Stream.chunk_every(20)
        |> Stream.flat_map(&verify_files/1)
        |> Stream.filter(fn {_, _, status} -> status == :missing end)
        |> Stream.map(&elem(&1, 0))
        |> Stream.chunk_every(20)
        |> Enum.reduce({0, 0}, &delete_files_reducer(repo, &1, &2))
        |> case do
          {_deleted, 0} ->
            :noop

          {_deleted, errored} ->
            Logger.warning("failed to delete #{errored} files")
        end

        {:ok, []}
      end,
      timeout: :infinity
    )
  end

  defp delete_files_reducer(repo, file_ids, {deleted_acc, error_acc}) do
    File
    |> where([f], f.id in ^file_ids)
    |> repo.delete_all()
    |> case do
      {count, _} ->
        {deleted_acc + count, error_acc}

      _ ->
        {deleted_acc, error_acc + length(file_ids)}
    end
  end

  defp verify_files(files) do
    files
    |> Task.async_stream(
      fn {id, path} ->
        status =
          case Elixir.File.stat(path) do
            {:ok, _stat} -> :exists
            {:error, :enoent} -> :missing
            {:error, reason} -> {:error, reason}
          end

        {id, path, status}
      end,
      max_concurrency: 3,
      timeout: 5_000,
      on_timeout: :kill_task
    )
    |> Enum.flat_map(fn
      {:ok, {id, path, :missing}} ->
        [{id, path, :missing}]

      {:ok, {_id, path, {:error, reason}}} ->
        Logger.warning("failed to verify #{path} (#{reason})")
        []

      {:ok, {_id, _path, :exists}} ->
        []

      {:exit, :timeout} ->
        Logger.warning("timeout while checking if files still exist")
        []
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
