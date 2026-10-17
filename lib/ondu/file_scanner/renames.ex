defmodule Ondu.FileScanner.Renames do
  @moduledoc """
  Albums and artists that were renamed (e.g. a typo was fixed) keep their
  original records, instead of appearing as newly inserted ones.
  """

  import Ecto.Query
  import Phoenix.Channel.Server, only: [broadcast: 4]

  alias Ondu.Albums
  alias Ondu.Albums.Album
  alias Ondu.Artists.Artist
  alias Ondu.Repo
  alias Ondu.Tracks.Track

  require Logger

  # Changed files could have a different album now, for example when the album
  # name was modified (e.g. a typo was fixed). Their tracks will record the
  # original album id so we can later correct this.
  @spec mark_previous_albums(Ecto.Repo.t(), map()) :: {:ok, map()}
  def mark_previous_albums(repo, %{changed_files: changed_files}) do
    previous_albums =
      changed_files.file_ids
      |> Enum.zip(changed_files.previous_album_ids)
      |> Enum.reject(fn {_file_id, album_id} -> is_nil(album_id) end)
      |> Enum.group_by(
        fn {_file_id, album_id} -> album_id end,
        fn {file_id, _album_id} -> file_id end
      )

    for {album_id, file_ids} <- previous_albums do
      from(t in Track, where: t.file_id in ^file_ids and t.album_id != ^album_id)
      |> repo.update_all(set: [previous_album_id: album_id])
    end

    {:ok, previous_albums}
  end

  @doc """
  This will update the existing album record with the new details, and point the
  tracks back to the original album, and delete the newly inserted album record.

  This is done to preserve all existing data (artwork, annotations, etc.) we
  have for albums instead, and to avoid having a scenario where fixing a typo
  in the album name results in it appearing as a newly added album.
  """
  @spec keep_renamed_albums() :: {:ok, %{albums: [Ecto.UUID.t()], artists: [Ecto.UUID.t()]}}
  def keep_renamed_albums do
    Repo.transact(fn ->
      renamed = find_renamed_albums()

      renamed_albums =
        Enum.map(renamed, fn {previous_album_id, album_id} ->
          keep_renamed_album(previous_album_id, album_id)
        end)

      # When the album artist was also renamed, we'll apply the same trick
      # to the artists.
      renamed_artists = find_renamed_artists(renamed_albums)

      for {previous_artist_id, artist_id} <- renamed_artists do
        keep_renamed_artist(previous_artist_id, artist_id)
      end

      # Now every renamed album should have been preserved, so we can clear
      # the previous_album_ids on the tracks.
      from(t in Track, where: not is_nil(t.previous_album_id))
      |> Repo.update_all(set: [previous_album_id: nil])

      # We'll invalidate artwork so the artwork fetcher will check if it needs
      # to replace the current artwork.
      album_ids = Enum.map(renamed, fn {previous_album_id, _album_id} -> previous_album_id end)
      Albums.invalidate_artworks(album_ids)

      artist_ids =
        Enum.map(renamed_artists, fn {previous_artist_id, _artist_id} -> previous_artist_id end)

      if album_ids != [] do
        broadcast(Ondu.PubSub, "library:sync", "processed", %{
          artists: artist_ids,
          albums: album_ids
        })
      end

      {:ok, %{albums: album_ids, artists: artist_ids}}
    end)
  end

  defp find_renamed_albums do
    # Get all albums marked as possible replacements
    marked =
      from(t in Track,
        where: not is_nil(t.previous_album_id),
        group_by: [t.album_id, t.previous_album_id],
        select: {t.album_id, t.previous_album_id, count(t.id)}
      )
      |> Repo.all()

    # Combine all album ids, new and old, into one list
    album_ids =
      Enum.flat_map(marked, fn {album_id, previous_album_id, _count} ->
        [album_id, previous_album_id]
      end)

    # Get the track count for every album, new and old
    # we do this to make sure all tracks can be moved to the
    # original album record.
    track_counts =
      from(t in Track,
        where: t.album_id in ^album_ids,
        group_by: t.album_id,
        select: {t.album_id, count(t.id)}
      )
      |> Repo.all()
      |> Map.new()

    marked
    |> Enum.filter(fn {album_id, previous_album_id, count} ->
      # We only want to revert to the previous_album_id when all its tracks have
      # moved to the new album, and the previous one has no tracks right now.
      all_moved? = Map.get(track_counts, album_id) == count
      previous_unused? = not Map.has_key?(track_counts, previous_album_id)
      all_moved? and previous_unused?
    end)
    |> Enum.group_by(fn {_album_id, previous_album_id, _count} -> previous_album_id end)
    |> Enum.filter(fn {_previous_album_id, albums} ->
      # We also want to ensure the tracks are not split over multiple new albums,
      # otherwise we should not revert them to the old album record.
      length(albums) == 1
    end)
    |> Enum.map(fn {previous_album_id, [{album_id, _previous_album_id, _count}]} ->
      {previous_album_id, album_id}
    end)
  end

  # This reverts the tracks back to the previous_album_id, as well as update
  # the album record with all the new details. The newly inserted album is also
  # deleted as it should not have any tracks anymore.
  defp keep_renamed_album(previous_album_id, album_id) do
    album = Repo.get!(Album, album_id)
    previous_album = Repo.get!(Album, previous_album_id)
    now = DateTime.utc_now(:second)

    from(t in Track, where: t.album_id == ^album_id)
    |> Repo.update_all(set: [album_id: previous_album_id, updated_at: now])

    Repo.delete!(album)

    from(al in Album, where: al.id == ^previous_album_id)
    |> Repo.update_all(
      set: [
        artist_id: album.artist_id,
        name: album.name,
        slug: album.slug,
        sort_name: album.sort_name,
        compilation: album.compilation,
        release_year: album.release_year,
        is_unknown: album.is_unknown,
        track_count: album.track_count,
        updated_at: now
      ]
    )

    Logger.info("Renamed album #{previous_album.name} to #{album.name}")

    {previous_album.artist_id, album.artist_id, previous_album_id}
  end

  # This takes the list of `keep_renamed_album/2` results, which contains the
  # previous album artist id, the new album artist id, and the previous
  # album id. Similar to albums, it will return artist that have been replaced
  # and no longer have any associated albums or tracks.
  defp find_renamed_artists(renamed_albums) do
    renamed_albums
    |> Enum.reject(fn {previous_artist_id, artist_id, _album_id} ->
      previous_artist_id == artist_id
    end)
    |> Enum.group_by(
      fn {previous_artist_id, artist_id, _album_id} -> {previous_artist_id, artist_id} end,
      fn {_previous_artist_id, _artist_id, album_id} -> album_id end
    )
    |> Enum.filter(fn {{previous_artist_id, artist_id}, album_ids} ->
      renamed_artist?(previous_artist_id, artist_id, album_ids)
    end)
    |> Enum.group_by(fn {{previous_artist_id, _artist_id}, _album_ids} -> previous_artist_id end)
    |> Enum.filter(fn {_previous_artist_id, artists} -> length(artists) == 1 end)
    |> Enum.map(fn {previous_artist_id, [{{_previous_artist_id, artist_id}, _album_ids}]} ->
      {previous_artist_id, artist_id}
    end)
  end

  defp renamed_artist?(previous_artist_id, artist_id, album_ids) do
    previous_used? =
      Repo.exists?(from(al in Album, where: al.artist_id == ^previous_artist_id)) or
        Repo.exists?(from(t in Track, where: t.artist_id == ^previous_artist_id))

    # The artist should only have the renamed albums, nothing else
    other_albums? =
      from(al in Album, where: al.artist_id == ^artist_id and al.id not in ^album_ids)
      |> Repo.exists?()

    # Same with tracks, the artist should not have any associated tracks anymore
    # that are not also related to one of the renamed albums.
    other_tracks? =
      from(t in Track,
        where: t.artist_id == ^artist_id,
        where: is_nil(t.album_id) or t.album_id not in ^album_ids
      )
      |> Repo.exists?()

    not previous_used? and not other_albums? and not other_tracks?
  end

  # Same as albums, the albums and tracks are reverted back to the previous
  # artist, which also gets the details of the new artist. It will then also
  # delete the newly inserted Artist record that should no longer have any
  # albums or tracks at this stage.
  defp keep_renamed_artist(previous_artist_id, artist_id) do
    artist = Repo.get!(Artist, artist_id)
    previous_artist = Repo.get!(Artist, previous_artist_id)
    now = DateTime.utc_now(:second)

    from(al in Album, where: al.artist_id == ^artist_id)
    |> Repo.update_all(set: [artist_id: previous_artist_id, updated_at: now])

    from(t in Track, where: t.artist_id == ^artist_id)
    |> Repo.update_all(set: [artist_id: previous_artist_id, updated_at: now])

    Repo.delete!(artist)

    from(a in Artist, where: a.id == ^previous_artist_id)
    |> Repo.update_all(
      set: [
        name: artist.name,
        slug: artist.slug,
        sort_name: artist.sort_name,
        album_count: artist.album_count,
        updated_at: now
      ]
    )

    Logger.info("Renamed artist #{previous_artist.name} to #{artist.name}")
  end
end
