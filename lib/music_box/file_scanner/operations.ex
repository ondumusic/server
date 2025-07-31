defmodule MusicBox.FileScanner.Operations do
  alias MusicBox.FileScanner.Analyzer
  alias MusicBox.Files.File
  alias MusicBox.Files.FileMetadata
  alias MusicBox.Artists.Artist
  alias MusicBox.Albums.Album
  alias MusicBox.Songs.Song
  alias MusicBox.Repo
  alias Ecto.Multi

  def batch_insert([]), do: :noop

  def batch_insert([%Analyzer.Result{} | _] = files) do
    Multi.new()
    |> Multi.run(:files, &maybe_create_files(&1, files, &2))
    |> Multi.run(:artists, &maybe_create_artists/2)
    |> Multi.run(:albums, &maybe_create_albums/2)
    |> Multi.run(:songs, &maybe_create_songs/2)
    |> Repo.transact()
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
          name: file.metadata.album
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
      |> Enum.reject(&is_nil(&1.metadata.artist))
      |> Enum.reject(&is_nil(&1.metadata.album))
      |> Enum.reject(&is_nil(&1.metadata.title))
      |> Enum.map(fn file ->
        match_artist = String.downcase(file.metadata.artist)
        match_album = String.downcase(file.metadata.album)
        artist = Enum.find(artists, &(String.downcase(&1.name) == match_artist))

        album =
          albums
          |> Enum.filter(&(&1.artist_id == artist.id))
          |> Enum.find(&(String.downcase(&1.name) == match_album))

        %{
          file: file,
          album: album
        }
      end)
      |> Enum.reject(&is_nil(&1.album))

    entries =
      linked_file_albums
      |> Enum.map(fn %{file: file, album: album} ->
        %{
          artist_id: album.artist_id,
          album_id: album.id,
          file_id: file.id,
          duration: file.metadata.duration,
          name: file.metadata.title
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
