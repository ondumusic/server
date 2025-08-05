defmodule MusicBox.FileScanner.Operations do
  alias MusicBox.FileScanner.Analyzer
  alias MusicBox.Files.File
  alias MusicBox.Files.FileMetadata
  alias MusicBox.Artists.Artist
  alias MusicBox.Albums.Album
  alias MusicBox.Songs.Song
  alias MusicBox.Repo
  alias Ecto.Multi

  import Ecto.Query

  def batch_insert([]), do: :noop

  def batch_insert([%Analyzer.Result{} | _] = files) do
    Multi.new()
    |> Multi.run(:files, &maybe_create_files(&1, files, &2))
    |> Multi.run(:artists, &maybe_create_artists/2)
    |> Multi.run(:albums, &maybe_create_albums/2)
    |> Multi.run(:songs, &maybe_create_songs/2)
    |> Repo.transact()
  end

  def filter_existing_paths([]), do: []

  def filter_existing_paths(paths) do
    from(f in File, where: f.path in ^paths, select: f.path)
    |> Repo.all()
  end

  def walk_entries([], _pipeline), do: :ok

  def walk_entries(entries, pipeline) when is_atom(pipeline) do
    Broadway.producer_names(pipeline)
    |> Enum.random()
    |> case do
      nil -> :noop
      producer -> GenStage.call(producer, {:walk, entries})
    end
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

  defp maybe_create_artists(repo, %{files: files}) do
    artist_names =
      files
      |> Enum.reject(&is_nil(&1.metadata.artist))
      |> Enum.map(& &1.metadata.artist)
      |> Enum.uniq_by(&String.downcase/1)

    entries =
      artist_names
      |> Enum.map(fn artist_name ->
        %{
          name: artist_name
        }
      end)
      |> Enum.map(&add_timestamps/1)

    {_num, artists} =
      repo.insert_all(Artist, entries,
        returning: true,
        conflict_target: [:name],
        on_conflict: {:replace_all_except, [:id, :inserted_at]}
      )

    {:ok, artists}
  end

  defp maybe_create_albums(repo, %{files: files, artists: artists}) do
    linked_file_artists =
      files
      |> Enum.reject(&is_nil(&1.metadata.artist))
      |> Enum.reject(&is_nil(&1.metadata.album))
      |> Enum.map(fn file ->
        match_artist = String.downcase(file.metadata.artist)
        artist = Enum.find(artists, &(String.downcase(&1.name) == match_artist))

        %{
          file: file,
          artist: artist
        }
      end)
      |> Enum.reject(&is_nil(&1.artist))

    artist_albums =
      linked_file_artists
      |> Enum.uniq_by(&String.downcase(&1.file.metadata.album))

    entries =
      artist_albums
      |> Enum.map(fn %{file: file, artist: artist} ->
        %{
          artist_id: artist.id,
          name: file.metadata.album,
          compilation: file.metadata.compilation,
          release_year: file.metadata.release_year
        }
      end)
      |> Enum.map(&add_timestamps/1)

    {_num, albums} =
      repo.insert_all(Album, entries,
        returning: true,
        conflict_target: [:artist_id, :name],
        on_conflict: {:replace_all_except, [:id, :inserted_at]}
      )

    {:ok, albums}
  end

  defp maybe_create_songs(repo, %{files: files, artists: artists, albums: albums}) do
    linked_file_albums =
      files
      |> Enum.map(fn %{metadata: metadata} = file ->
        album =
          if is_binary(metadata.artist) and is_binary(metadata.album) do
            match_artist = String.downcase(metadata.artist)
            match_album = String.downcase(metadata.album)
            artist = Enum.find(artists, &(String.downcase(&1.name) == match_artist))

            albums
            |> Enum.filter(&(&1.artist_id == artist.id))
            |> Enum.find(&(String.downcase(&1.name) == match_album))
          end

        %{
          file: file,
          album: album
        }
      end)

    entries =
      linked_file_albums
      |> Enum.map(fn %{file: file, album: album} ->
        title =
          case file.metadata.title do
            nil -> Path.basename(file.path)
            title -> title
          end

        %{
          artist_id: album && album.artist_id,
          album_id: album && album.id,
          file_id: file.id,
          duration: file.metadata.duration,
          track: file.metadata.track,
          name: title
        }
      end)
      |> Enum.map(&add_timestamps/1)

    {_num, songs} =
      repo.insert_all(Song, entries,
        returning: true,
        conflict_target: [:file_id],
        on_conflict: {:replace_all_except, [:id, :inserted_at]}
      )

    {:ok, songs}
  end

  defp add_timestamps(entry, additional_fields \\ []) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    date_fields = [:inserted_at, :updated_at] ++ additional_fields

    Enum.reduce(date_fields, entry, fn field, entry ->
      Map.put(entry, field, now)
    end)
  end
end
