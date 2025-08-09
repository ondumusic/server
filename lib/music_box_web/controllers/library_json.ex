defmodule MusicBoxWeb.LibraryJSON do
  def album_artists(%{page: page}) do
    page
    |> Map.take([:page_number, :page_size, :total_entries, :total_pages])
    |> Map.put(:entries, Enum.map(page.entries, &album_artist(%{album_artist: &1})))
  end

  def album_artist(%{album_artist: album_artist}) do
    %{
      id: album_artist.id,
      name: album_artist.name,
      slug: album_artist.slug,
      albumCount: album_artist.album_count
    }
  end

  def artist(%{artist: artist}) do
    %{
      id: artist.id,
      name: artist.name
    }
  end

  def albums(%{page: page}) do
    page
    |> Map.take([:page_number, :page_size, :total_entries, :total_pages])
    |> Map.put(:entries, Enum.map(page.entries, &album(%{album: &1})))
  end

  def album(%{album: %{songs: songs} = album}) when is_list(songs) do
    %{
      id: album.id,
      albumArtistId: album.album_artist_id,
      name: album.name,
      releaseYear: album.release_year,
      songs: Enum.map(songs, &song(%{song: &1, album: album}))
    }
  end

  def album(%{album: album}) do
    %{
      id: album.id,
      albumArtistId: album.album_artist_id,
      name: album.name,
      releaseYear: album.release_year
    }
  end

  def song(%{song: song, album: album}) do
    %{
      id: song.id,
      artistId: song.artist_id,
      artist: artist(%{artist: song.artist}),
      albumId: album.id,
      albumArtistId: album.album_artist_id,
      name: song.name,
      disc: song.disc,
      track: song.track,
      duration: song.duration
    }
  end
end
