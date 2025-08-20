defmodule MusicBoxWeb.LibraryJSON do
  use MusicBoxWeb, :json
  alias MusicBoxWeb.SharedTrack

  def artists(%{page: page} = assigns) do
    %{
      __type: "page",
      __subtype: "artist",
      pageNumber: page.page_number,
      pageSize: page.page_size,
      totalEntries: page.total_entries,
      totalPages: page.total_pages,
      entries: json_map(assigns, [:page, :entries], :artist)
    }
  end

  def artist(%{artist: artist}) do
    %{
      __type: "artist",
      id: artist.id,
      name: artist.name,
      slug: artist.slug,
      albumCount: artist.album_count
    }
  end

  def albums(%{page: page} = assigns) do
    %{
      __type: "page",
      __subtype: "album",
      pageNumber: page.page_number,
      pageSize: page.page_size,
      totalEntries: page.total_entries,
      totalPages: page.total_pages,
      entries: json_map(assigns, [:page, :entries], :album)
    }
  end

  def album(%{album: album} = assigns) do
    %{
      __type: "album",
      id: album.id,
      slug: album.slug,
      artistId: album.artist_id,
      name: album.name,
      releaseYear: album.release_year,
      isUnknown: album.is_unknown,
      tracks: json_map(assigns, [:album, :tracks], :track, include: [:album])
    }
  end

  def track(%{track: track, album: album, conn: conn}) do
    signed_token = conn |> SharedTrack.create(track.id) |> URI.encode()

    %{
      __type: "track",
      id: track.id,
      artistId: track.artist_id,
      albumArtistId: album.artist_id,
      artist: artist(%{artist: track.artist}),
      albumId: album.id,
      name: track.name,
      disc: track.disc,
      number: track.number,
      duration: track.duration,
      streamUrl: ~p"/stream/#{track}?token=#{signed_token}"
    }
  end
end
