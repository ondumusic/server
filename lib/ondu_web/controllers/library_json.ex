defmodule OnduWeb.LibraryJSON do
  use OnduWeb, :json

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
      artwork: artwork(:artists, artist.id, artist.artwork),
      insertedAt: json_datetime(artist.inserted_at)
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
      entries: json_map(assigns, [:page, :entries], :album, include: [:render_album])
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
    artwork = artwork(:albums, album.id, album.artwork)

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
      artwork: artwork,
      loudness: album_loudness(album),
      insertedAt: json_datetime(album.inserted_at)
    }

    if assigns[:render_tracks] != false do
      Map.put(
        item,
        :tracks,
        # Tracks of an album are always flat, without their album and artist.
        json_map(assigns, [:album, :tracks], :track,
          include: [:album],
          as: &track(Map.merge(&1, %{render_album: false, render_artist: false}))
        )
      )
    else
      item
    end
  end

  def track(%{track: track, album: album} = assigns) do
    mimetype = Ondu.Files.File.mimetype(track.file)

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
      loudness: loudness(track.file.loudness),
      playCount: track.play_count,
      lastPlayedAt: track.last_played_at,
      mimetype: mimetype,
      insertedAt: json_datetime(track.inserted_at),
      downloadUrl: url(~p"/download/#{track}"),
      streamUrl: url(~p"/stream/#{track}"),
      relativeFilePath: track.file.path
    }

    item =
      if assigns[:render_album] != false do
        Map.put(item, :album, album(%{album: album, render_tracks: false}))
      else
        item
      end

    item =
      if assigns[:render_artist] != false do
        Map.put(item, :artist, artist(%{artist: track.artist}))
      else
        item
      end

    item
  end

  def track(%{track: %{album: album}} = assigns),
    do: track(Map.put(assigns, :album, album))

  # A failed measurement is stored without values, for clients that is the same
  # as not measured yet.
  defp loudness(%{lufs: lufs, peak: peak}) when is_float(lufs), do: %{lufs: lufs, peak: peak}
  defp loudness(_loudness), do: nil

  # Derived from the tracks, which are not loaded everywhere albums are rendered.
  defp album_loudness(%{tracks: tracks}) when is_list(tracks),
    do: Ondu.Loudness.album_loudness(tracks)

  defp album_loudness(_album), do: nil

  # Ordered from smallest to largest.
  defp artwork(kind, id, %{hash: hash, width: width} = artwork)
       when is_binary(hash) and is_integer(width) do
    for {variant, width, height} <- Ondu.Artwork.variant_sizes(kind, artwork) do
      filename = "#{variant}.jpg"
      %{url: url(~p"/artwork/#{kind}/#{id}/#{hash}/#{filename}"), width: width, height: height}
    end
  end

  defp artwork(_kind, _id, _artwork), do: []
end
