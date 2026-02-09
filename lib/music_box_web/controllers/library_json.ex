defmodule MusicBoxWeb.LibraryJSON do
  use MusicBoxWeb, :json

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

  def tracks(%{page: page} = assigns) do
    %{
      __type: "page",
      __subtype: "track",
      pageNumber: page.page_number,
      pageSize: page.page_size,
      totalEntries: page.total_entries,
      totalPages: page.total_pages,
      entries: json_map(assigns, [:page, :entries], :track)
    }
  end

  def album(%{album: album} = assigns) do
    artwork_filename =
      case album do
        %{artwork: %{path: path}} when is_binary(path) -> Path.basename(path)
        _ -> nil
      end

    artwork_url =
      if artwork_filename,
        do: ~p"/artwork/#{artwork_filename}"

    %{
      __type: "album",
      id: album.id,
      slug: album.slug,
      artistId: album.artist_id,
      name: album.name,
      releaseYear: album.release_year,
      isUnknown: album.is_unknown,
      artworkUrl: artwork_url,
      tracks: json_map(assigns, [:album, :tracks], :track, include: [:album])
    }
  end

  def track(%{track: track, album: album}) do
    mimetype = MusicBox.Files.File.mimetype(track.file)

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
      mimetype: mimetype,
      streamUrl: ~p"/stream/#{track}"
    }
  end

  def track(%{track: %{album: album} = track}),
    do: track(%{track: track, album: album})
end
