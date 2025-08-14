defmodule MusicBoxWeb.LibraryJSON do
  use MusicBoxWeb, :verified_routes

  def artists(%{page: page}) do
    %{
      pageNumber: page.page_number,
      pageSize: page.page_size,
      totalEntries: page.total_entries,
      totalPages: page.total_pages,
      entries: Enum.map(page.entries, &artist(%{artist: &1}))
    }
  end

  def artist(%{artist: artist}) do
    %{
      id: artist.id,
      name: artist.name,
      slug: artist.slug,
      albumCount: artist.album_count
    }
  end

  def albums(%{page: page}) do
    %{
      pageNumber: page.page_number,
      pageSize: page.page_size,
      totalEntries: page.total_entries,
      totalPages: page.total_pages,
      entries: Enum.map(page.entries, &album(%{album: &1}))
    }
  end

  def album(%{album: %{tracks: tracks} = album}) when is_list(tracks) do
    %{
      id: album.id,
      slug: album.slug,
      artistId: album.artist_id,
      name: album.name,
      releaseYear: album.release_year,
      tracks: Enum.map(tracks, &track(%{track: &1, album: album}))
    }
  end

  def track(%{track: track, album: album}) do
    %{
      id: track.id,
      artistId: track.artist_id,
      albumArtistId: album.artist_id,
      artist: artist(%{artist: track.artist}),
      albumId: album.id,
      name: track.name,
      disc: track.disc,
      number: track.number,
      duration: track.duration,
      streamUrl: url(~p"/stream/#{track}")
    }
  end
end
