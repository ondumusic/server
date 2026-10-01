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
    artwork = artwork(album)

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
      insertedAt: album.inserted_at
    }

    if assigns[:render_tracks] != false do
      Map.put(
        item,
        :tracks,
        json_map(assigns, [:album, :tracks], :track, include: [:album, :render_album])
      )
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
      loudness: loudness(track.file.loudness),
      playCount: track.play_count,
      lastPlayedAt: track.last_played_at,
      mimetype: mimetype,
      insertedAt: track.inserted_at,
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
      if assigns[:render_album] != false do
        Map.put(item, :artist, artist(%{artist: track.artist}))
      else
        item
      end

    item
  end

  def track(%{track: %{album: album} = track}),
    do: track(%{track: track, album: album})

  # A failed measurement is stored without values, for clients that is the same
  # as not measured yet.
  defp loudness(%{lufs: lufs, peak: peak}) when is_float(lufs), do: %{lufs: lufs, peak: peak}
  defp loudness(_loudness), do: nil

  # Derived from the tracks, which are not loaded everywhere albums are rendered.
  defp album_loudness(%{tracks: tracks}) when is_list(tracks),
    do: MusicBox.Loudness.album_loudness(tracks)

  defp album_loudness(_album), do: nil

  # Ordered from smallest to largest.
  defp artwork(%{id: album_id, artwork: %{hash: hash, width: width} = artwork})
       when is_binary(hash) and is_integer(width) do
    for {variant, width, height} <- MusicBox.Artwork.variant_sizes(:albums, artwork) do
      filename = "#{variant}.jpg"

      %{
        url: url(~p"/artwork/albums/#{album_id}/#{hash}/#{filename}"),
        width: width,
        height: height
      }
    end
  end

  defp artwork(_album), do: []
end
