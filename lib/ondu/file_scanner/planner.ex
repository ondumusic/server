defmodule Ondu.FileScanner.Planner do
  @moduledoc """
  This module decides what happens to deferred files and files that appear
  missing. It will try to figure out whether the files are new, moved,
  replaced or deleted.

  It does not write any changes to the database, it only returns a plan
  which can be applied afterwards.
  """

  import Ecto.Query

  alias Ondu.Albums.Album
  alias Ondu.Artists.Artist
  alias Ondu.Files.{File, FileMetadata}
  alias Ondu.FileScanner.{Analyzer, Moves, Plan, Replacements, Utils}
  alias Ondu.Repo
  alias Ondu.Tracks.Track

  @spec plan([Analyzer.Result.t()], [Ecto.UUID.t()]) :: Plan.t()
  def plan(deferred, missing_file_ids) do
    missing_files = load_missing_files(missing_file_ids)
    album_by_path = lookup_album_ids_for_paths(deferred)
    new_files = Enum.reject(deferred, &Map.has_key?(album_by_path, &1.path))

    # Moves are the most certain match (same size and tags),
    # so we deal with them first.
    moves = Moves.match(missing_files, new_files)
    moved_file_ids = MapSet.new(moves, fn {file, _new_file} -> file.id end)
    moved_paths = MapSet.new(moves, fn {_file, new_file} -> new_file.path end)

    # Next we will proceed with the remaining files that weren't moved and
    # convert them to replacement candidates, so we can compare them properly.
    missing_candidates =
      missing_files
      |> Enum.reject(fn file ->
        moved? = MapSet.member?(moved_file_ids, file.id)
        without_track? = is_nil(file.track)

        # If the file has already been moved or does not have a track it
        # cannot be a replacement so we can skip it.
        moved? or without_track?
      end)
      |> Enum.map(&Replacements.to_candidate/1)

    new_candidates =
      new_files
      |> Enum.reject(&MapSet.member?(moved_paths, &1.path))
      |> Enum.map(&Replacements.to_candidate/1)

    # Compare the missing and new candidates to figure out whether or not
    # anything got replaced.
    replacements = Replacements.match(missing_candidates, new_candidates)
    replaced_file_ids = MapSet.new(replacements, fn {old, _new} -> old.file_id end)

    # Any missing file that's not detected as moved or replaced should be deleted
    kept_file_ids = MapSet.union(moved_file_ids, replaced_file_ids)
    deleted_file_ids = Enum.reject(missing_file_ids, &MapSet.member?(kept_file_ids, &1))

    # For missing, replaced and moved files we'll create a map with their
    # album id (or nil) allowing quick lookups based on file id or path.
    album_by_missing_file =
      Map.new(missing_files, fn file -> {file.id, album_id(file)} end)

    album_by_moved_path =
      Map.new(moves, fn {file, new_file} -> {new_file.path, album_id(file)} end)

    album_by_replaced_path =
      Map.new(replacements, fn {old, new} ->
        {new.path, Map.fetch!(album_by_missing_file, old.file_id)}
      end)

    # Combine the album lookup maps for deferred, moved and replaced file paths
    current_albums =
      album_by_path
      |> Map.merge(album_by_moved_path)
      |> Map.merge(album_by_replaced_path)
      |> Map.reject(fn {_path, album_id} -> is_nil(album_id) end)

    # This maps file ids to their respective album ids, and for the ones that
    # have an album_id (not nil) it counts the amount of files for that album id
    # which indicates the amount of deleted tracks for an album.
    deleted_tracks_per_album =
      deleted_file_ids
      |> Enum.map(&Map.get(album_by_missing_file, &1))
      |> Enum.reject(&is_nil/1)
      |> Enum.frequencies()

    # Now let's find out which albums were actually renamed
    renamed_albums = find_renamed_albums(deferred, current_albums, deleted_tracks_per_album)

    # And let's do the same for artists
    renamed_artists = find_renamed_artists(renamed_albums, deferred, current_albums)

    # Finally return the plan
    %Plan{
      moved_files: Enum.map(moves, fn {file, new_file} -> to_move(file.id, file, new_file) end),
      replaced_files: Enum.map(replacements, fn {old, new} -> to_move(old.file_id, old, new) end),
      renamed_albums: Enum.map(renamed_albums, &to_renamed_album/1),
      renamed_artists: Enum.map(renamed_artists, &to_renamed_artist/1),
      deleted_files: deleted_file_ids,
      saved_files: deferred
    }
  end

  @spec needs_plan?(Analyzer.Result.t(), %{String.t() => FileMetadata.t()}) :: boolean()
  def needs_plan?(file, known_metadata) do
    case Map.fetch(known_metadata, file.path) do
      {:ok, metadata} -> album_or_artist_changed?(metadata, file.metadata)
      :error -> true
    end
  end

  defp album_or_artist_changed?(old, new) do
    artist_changed? = Utils.slugify(old.artist) != Utils.slugify(new.artist)
    album_artist_changed? = Utils.slugify(old.album_artist) != Utils.slugify(new.album_artist)
    album_changed? = Utils.slugify(old.album) != Utils.slugify(new.album)

    artist_changed? or album_artist_changed? or album_changed?
  end

  defp to_move(file_id, old, new), do: %{file_id: file_id, from: old.path, to: new.path}

  # Files with the same album key can still differ in spelling (e.g. "The artist"
  # and "The Artist"), like the upsert we use the names of the first file.
  defp to_renamed_album(%{album: album, files: [file | _files]}) do
    %{album_id: album.id, album_artist: file.metadata.album_artist, album: file.metadata.album}
  end

  # Like albums, we use the name of the first file.
  defp to_renamed_artist({artist_id, renamed}) do
    [file | _files] = List.first(renamed).files
    %{artist_id: artist_id, artist: file.metadata.album_artist}
  end

  defp album_id(%File{track: %Track{album_id: album_id}}), do: album_id
  defp album_id(%File{}), do: nil

  defp find_renamed_albums(deferred, current_albums, deleted_tracks_per_album) do
    # Group deferred files by album_id (if present)
    changed =
      deferred
      |> Enum.filter(&Map.has_key?(current_albums, &1.path))
      |> Enum.group_by(&Map.fetch!(current_albums, &1.path))

    # Group deferred files by an album key ({artist, album} tuple)
    # that's generated from the file metadata/tags, and then load
    # them from db so we can see which already exist.
    files_by_key = Enum.group_by(deferred, &album_key/1)
    existing_keys = load_existing_album_keys(Map.keys(files_by_key))

    # Load album data for all changed albums
    albums = load_albums(Map.keys(changed))

    # Iterate over all changed albums and maps them to tuples containing
    # the album data and list of deferred files.
    changed
    |> Enum.map(fn {album_id, files} -> {Map.fetch!(albums, album_id), files} end)
    |> Enum.filter(fn {album, files} ->
      # Generate a unique list of album keys for the deferred files
      keys = files |> Enum.map(&album_key/1) |> Enum.uniq()
      key = List.first(keys)

      # If there is only one album key, or multiple.
      one_album? = length(keys) == 1

      # If there is an album key and it does not match the current album key
      # we can mark it as renamed.
      renamed? = not is_nil(key) and key != album.key

      # If the album key is not in our list of existing keys this should count
      # as a new album.
      new_album? = not MapSet.member?(existing_keys, key)

      # The file count (plus any deleted tracks) should match the expected
      # album track count.
      deleted_tracks = Map.get(deleted_tracks_per_album, album.id, 0)
      all_tracks? = length(files) + deleted_tracks == album.track_count

      # Ensure that there are no other files belonging to this album.
      other_albums? =
        files_by_key
        |> Map.get(key, [])
        |> Enum.any?(&other_track?(&1, current_albums, album.id))

      # Now combine all check results to determine whether or not
      # this should count as a renamed album.
      one_album? and renamed? and new_album? and all_tracks? and not other_albums?
    end)
    |> Enum.map(fn {album, files} ->
      {artist_slug, _album_slug} = album_key(List.first(files))
      %{artist_slug: artist_slug, album: album, files: files}
    end)
  end

  defp find_renamed_artists(renamed_albums, deferred, current_albums) do
    # Group renamed albums by artist id, and only include artists
    # that have also been renamed.
    renamed_by_artist =
      renamed_albums
      |> Enum.reject(fn renamed -> renamed.artist_slug == renamed.album.artist_slug end)
      |> Enum.group_by(fn renamed -> renamed.album.artist_id end)

    # For every renamed artist get the album counts, which we'll use later
    # to determine whether or not all of their albums refer to the new artist.
    artist_ids = Map.keys(renamed_by_artist)
    album_counts = count_albums(artist_ids)

    # Find artists that have tracks outside of the list of renamed album ids,
    # for example as the artist of a track on another album.
    album_ids = Enum.map(renamed_albums, & &1.album.id)
    with_other_tracks = find_artists_with_other_tracks(artist_ids, album_ids)

    # Group the deferred file paths by the artist slug, and then load
    # the ones that already exist in the database.
    paths_by_artist = paths_by_artist(deferred)
    existing_slugs = renamed_albums |> Enum.map(& &1.artist_slug) |> load_existing_artist_slugs()

    # Iterate over the artists and their renamed albums.
    renamed_by_artist
    |> Enum.filter(fn {artist_id, renamed} ->
      # The current artist slug should be the same for all of these albums.
      current_slug = List.first(renamed).album.artist_slug

      # Generate a unique list of new artist slugs for the renamed albums.
      slugs = renamed |> Enum.map(& &1.artist_slug) |> Enum.uniq()
      slug = List.first(slugs)

      # All albums should have the same artist.
      one_artist? = length(slugs) == 1

      # If the new artist is not in our list of existing artists
      # this should count as a new artist.
      new_artist? = not MapSet.member?(existing_slugs, slug)

      # Every album of the artist should have been renamed,
      # otherwise the current artist is still in use.
      all_albums? = length(renamed) == Map.get(album_counts, artist_id, 0)

      # The current artist should not have any tracks
      # outside of the renamed albums either.
      other_tracks? = MapSet.member?(with_other_tracks, artist_id)

      # No deferred file should still use the current artist, for example when
      # only the album artist was changed and the track artist was not.
      still_used? = Map.has_key?(paths_by_artist, current_slug)

      # The new artist should not be used by tracks of other albums,
      # new files are fine though.
      paths = renamed |> Enum.flat_map(& &1.files) |> MapSet.new(& &1.path)

      used_by_others? =
        paths_by_artist
        |> Map.get(slug, MapSet.new())
        |> Enum.any?(fn path ->
          existing_track? = Map.has_key?(current_albums, path)
          existing_track? and not MapSet.member?(paths, path)
        end)

      # Now combine all check results to determine whether or not
      # this should count as a renamed artist.
      one_artist? and new_artist? and all_albums? and not other_tracks? and not still_used? and
        not used_by_others?
    end)
  end

  # Returns the paths of the deferred files for every artist (by slug) they
  # use, either as the track artist or the album artist.
  defp paths_by_artist(deferred) do
    deferred
    |> Enum.flat_map(fn file ->
      [file.metadata.artist, file.metadata.album_artist]
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&{Utils.slugify(&1), file.path})
    end)
    |> Enum.group_by(fn {slug, _path} -> slug end, fn {_slug, path} -> path end)
    |> Map.new(fn {slug, paths} -> {slug, MapSet.new(paths)} end)
  end

  # Whether the file belongs to an existing track of another album.
  defp other_track?(file, current_albums, album_id) do
    current_album_id = Map.get(current_albums, file.path)
    not is_nil(current_album_id) and current_album_id != album_id
  end

  # An album key is a tuple of {artist.slug, album.slug}
  defp album_key(%Analyzer.Result{metadata: metadata}) do
    has_album? = is_binary(metadata.album_artist) and is_binary(metadata.album)

    if has_album?,
      do: {Utils.slugify(metadata.album_artist), Utils.slugify(metadata.album)}
  end

  defp load_albums(album_ids) do
    album_ids
    |> Enum.chunk_every(1000)
    |> Enum.flat_map(fn ids ->
      from(al in Album,
        join: a in assoc(al, :artist),
        left_join: t in assoc(al, :tracks),
        where: al.id in ^ids,
        group_by: [al.id, al.artist_id, a.slug, al.slug],
        select:
          {al.id,
           %{
             id: al.id,
             artist_id: al.artist_id,
             artist_slug: a.slug,
             key: {a.slug, al.slug},
             track_count: count(t.id)
           }}
      )
      |> Repo.all()
    end)
    |> Map.new()
  end

  defp count_albums(artist_ids) do
    from(al in Album,
      where: al.artist_id in ^artist_ids,
      group_by: al.artist_id,
      select: {al.artist_id, count(al.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  defp find_artists_with_other_tracks(artist_ids, album_ids) do
    from(t in Track,
      where: t.artist_id in ^artist_ids,
      where: is_nil(t.album_id) or t.album_id not in ^album_ids,
      distinct: true,
      select: t.artist_id
    )
    |> Repo.all()
    |> MapSet.new()
  end

  defp load_existing_artist_slugs(slugs) do
    slugs
    |> Enum.uniq()
    |> Enum.chunk_every(1000)
    |> Enum.flat_map(fn slugs ->
      from(a in Artist, where: a.slug in ^slugs, select: a.slug)
      |> Repo.all()
    end)
    |> MapSet.new()
  end

  defp load_existing_album_keys(keys) do
    keys
    |> Enum.reject(&is_nil/1)
    |> Enum.map(fn {_artist_slug, album_slug} -> album_slug end)
    |> Enum.uniq()
    |> Enum.chunk_every(1000)
    |> Enum.flat_map(fn slugs ->
      from(al in Album,
        join: a in assoc(al, :artist),
        where: al.slug in ^slugs,
        select: {a.slug, al.slug}
      )
      |> Repo.all()
    end)
    |> MapSet.new()
  end

  defp load_missing_files(file_ids) do
    file_ids
    |> Enum.chunk_every(1000)
    |> Enum.flat_map(fn ids ->
      from(f in File, where: f.id in ^ids, preload: :track)
      |> Repo.all()
    end)
  end

  defp lookup_album_ids_for_paths(files) do
    files
    |> Enum.map(& &1.path)
    |> Enum.chunk_every(1000)
    |> Enum.flat_map(fn paths ->
      from(f in File,
        left_join: t in assoc(f, :track),
        where: f.path in ^paths,
        select: {f.path, t.album_id}
      )
      |> Repo.all()
    end)
    |> Map.new()
  end
end
