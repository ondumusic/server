defmodule MusicBoxWeb.LibraryJSON do
  def artists(%{page: page}) do
    page
    |> Map.take([:page_number, :page_size, :total_entries, :total_pages])
    |> Map.put(:entries, Enum.map(page.entries, &artist(%{artist: &1})))
  end

  def artist(%{artist: artist}) do
    %{
      id: artist.id,
      name: artist.name,
      albumCount: artist.album_count
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
      artistId: album.artist_id,
      name: album.name,
      releaseYear: album.release_year,
      songs: Enum.map(songs, &song(%{song: &1}))
    }
  end

  def album(%{album: album}) do
    %{
      id: album.id,
      artistId: album.artist_id,
      name: album.name,
      releaseYear: album.release_year
    }
  end

  def song(%{song: song}) do
    %{
      id: song.id,
      artistId: song.artist_id,
      albumId: song.album_id,
      name: song.name,
      disc: song.disc,
      track: song.track,
      duration: song.duration
    }
  end
end
