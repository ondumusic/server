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
      sortName: artist.sort_name,
      slug: artist.slug,
      albumCount: artist.album_count,
      insertedAt: artist.inserted_at
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
        do: url(~p"/artwork/#{artwork_filename}")

    item = %{
      __type: "album",
      id: album.id,
      slug: album.slug,
      artistId: album.artist_id,
      name: album.name,
      sortName: album.sort_name,
      releaseYear: album.release_year,
      isUnknown: album.is_unknown,
      trackCount: album.track_count,
      artworkUrl: artwork_url,
      insertedAt: album.inserted_at
    }

    if assigns[:render_tracks] != false do
      Map.put(item, :tracks, json_map(assigns, [:album, :tracks], :track, include: [:album]))
    else
      item
    end
  end

  def track(%{track: track, album: album} = assigns) do
    mimetype = MusicBox.Files.File.mimetype(track.file)

    item = %{
      __type: "track",
      id: track.id,
      artistId: track.artist_id,
      albumArtistId: album.artist_id,
      albumId: album.id,
      name: track.name,
      disc: track.disc,
      number: track.number,
      duration: track.duration,
      mimetype: mimetype,
      insertedAt: track.inserted_at,
      downloadUrl: url(~p"/download/#{track}"),
      streamUrl: url(~p"/stream/#{track}")
    }

    item =
      if assigns[:render_album] != false do
        Map.put(item, :album, album(%{album: album, render_tracks: false}))
      else
        item
      end

    item =
      if assigns[:render_album] != false do
        Map.put(item, :artist, artist(%{artist: track.artist}))
      else
        item
      end

    item
  end

  def track(%{track: %{album: album} = track}),
    do: track(%{track: track, album: album})
end
