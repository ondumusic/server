defmodule Ondu.FileFixtures do
  @moduledoc false

  alias Ondu.Albums.Album
  alias Ondu.Artists.Artist
  alias Ondu.Files.{File, FileMetadata}
  alias Ondu.FileScanner.Analyzer.{Metadata, Result}
  alias Ondu.FileScanner.Utils
  alias Ondu.Repo
  alias Ondu.Tracks.Track

  @default_tags %{
    artist: "Artist",
    album_artist: "Artist",
    album: "Album",
    title: "Song",
    track: 1,
    disc: 1,
    duration: 201.5
  }

  @doc "Inserts a file and ensure artist, album and track records exist."
  def insert_file(path, size, tags \\ %{}) do
    %Result{metadata: metadata} = scanned_file(path, size, tags)

    file =
      Repo.insert!(%File{
        path: path,
        size: size,
        metadata:
          %FileMetadata{}
          |> FileMetadata.changeset(Map.from_struct(metadata))
          |> Ecto.Changeset.apply_changes(),
        last_modified_at: ~U[2026-01-01 00:00:00Z]
      })

    album_id =
      if metadata.album_artist,
        do: insert_album(metadata.album_artist, metadata.album).id

    artist_id =
      if metadata.artist,
        do: insert_artist(metadata.artist).id

    Repo.insert!(%Track{
      file_id: file.id,
      album_id: album_id,
      artist_id: artist_id,
      name: metadata.title,
      duration: metadata.duration
    })

    file
  end

  @doc "Returns a file as the scanner would have analyzed it."
  def scanned_file(path, size, tags \\ %{}) do
    %Result{
      path: path,
      size: size,
      type: :flac,
      last_modified_at: DateTime.utc_now(:second),
      metadata: struct!(Metadata, Map.merge(@default_tags, tags))
    }
  end

  defp insert_artist(name) do
    Repo.get_by(Artist, slug: Utils.slugify(name)) ||
      Repo.insert!(%Artist{name: name, slug: Utils.slugify(name)})
  end

  defp insert_album(artist_name, album_name) do
    artist = insert_artist(artist_name)

    Repo.get_by(Album, artist_id: artist.id, slug: Utils.slugify(album_name)) ||
      Repo.insert!(%Album{
        artist_id: artist.id,
        name: album_name,
        slug: Utils.slugify(album_name)
      })
  end
end
