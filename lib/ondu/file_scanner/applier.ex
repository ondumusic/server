defmodule Ondu.FileScanner.Applier do
  @moduledoc """
  This module applies a plan made by the Planner module.

  Because the plan already contains the exact changes that need to be written
  to the database, this module is pretty simple. It will first apply all the
  necessary changes, then deal with upserts and finally with the deletions.

  Yes, Applier is a silly name but I couldn't think of a better one.
  """

  import Ecto.Query

  alias Ondu.Albums
  alias Ondu.Albums.Album
  alias Ondu.Artists.Artist
  alias Ondu.Files.File
  alias Ondu.FileScanner.{Deletions, Operations, Plan, Utils}
  alias Ondu.Repo
  alias Ondu.Settings
  alias Ondu.Tracks.Track

  require Logger

  @spec apply(Plan.t()) :: :ok
  def apply(%Plan{} = plan) do
    settings = Settings.get()

    # The existing records are updated in one transaction, because we don't
    # want a failure to result in a partial update.
    {:ok, _updated} =
      Repo.transact(fn ->
        rename_artists(plan.renamed_artists, settings)
        rename_albums(plan.renamed_albums, settings)
        move_files(plan.moved_files, plan.saved_files)
        replace_files(plan.replaced_files)
        {:ok, :updated}
      end)

    # Next we can upsert our saved files
    plan.saved_files
    |> Enum.chunk_every(20)
    |> Enum.each(&save_batch/1)

    # And finally, delete the deleted files
    {:ok, _deleted} = Deletions.delete_files(plan.deleted_files)

    :ok
  end

  defp rename_artists(renamed_artists, settings) do
    now = DateTime.utc_now(:second)

    for %{artist_id: artist_id, artist: name} <- renamed_artists do
      artist = Repo.get!(Artist, artist_id)

      from(a in Artist, where: a.id == ^artist_id)
      |> Repo.update_all(
        set: [
          name: name,
          slug: Utils.slugify(name),
          sort_name: Utils.sort_name(name, strip_prefixes: settings.strip_sort_prefixes),
          updated_at: now
        ]
      )

      Logger.info("Renamed artist #{artist.name} to #{name}")
    end
  end

  defp rename_albums(renamed_albums, settings) do
    now = DateTime.utc_now(:second)

    # First we get or create the artist entries per album artist (by slug),
    # as multiple albums could have the same artist.
    artist_by_slug =
      renamed_albums
      |> Enum.map(& &1.album_artist)
      |> Enum.uniq_by(&Utils.slugify/1)
      |> Map.new(&{Utils.slugify(&1), find_or_create_artist(&1, settings)})

    # Then we rename the albums
    for %{album_id: album_id, album_artist: album_artist, album: name} <- renamed_albums do
      album = Repo.get!(Album, album_id)
      artist = Map.fetch!(artist_by_slug, Utils.slugify(album_artist))

      from(al in Album, where: al.id == ^album_id)
      |> Repo.update_all(
        set: [
          artist_id: artist.id,
          name: name,
          slug: Utils.slugify(name),
          sort_name: Utils.sort_name(name, strip_prefixes: settings.strip_sort_prefixes),
          updated_at: now
        ]
      )

      Logger.info("Renamed album #{album.name} to #{name}")
    end

    # Invalidate artwork too, just in case artwork was modified.
    renamed_albums
    |> Enum.map(& &1.album_id)
    |> Albums.invalidate_artworks()
  end

  defp move_files(moved_files, saved_files) do
    last_modified_at = Map.new(saved_files, &{&1.path, &1.last_modified_at})

    # We'll update the file paths and last_modified_at, otherwise the later
    # upsert will mark it as changed again (which is not needed because for
    # moved files we already compared the tags and they are the same)
    for move <- moved_files do
      from(f in File, where: f.id == ^move.file_id)
      |> Repo.update_all(
        set: [path: move.to, last_modified_at: Map.fetch!(last_modified_at, move.to)]
      )

      Logger.info("Moved #{move.from} to #{move.to}")
    end

    # While it looks like a simple move, it's possible the artwork changed
    # too so we'll have to invalidate the artwork here too.
    moved_files
    |> Enum.map(& &1.file_id)
    |> Enum.chunk_every(1000)
    |> Enum.flat_map(fn file_ids ->
      from(t in Track, where: t.file_id in ^file_ids, distinct: true, select: t.album_id)
      |> Repo.all()
    end)
    |> Albums.invalidate_artworks()
  end

  defp replace_files(replaced_files) do
    # For replaced files we only update file paths, then when upsert happens
    # it will detect it as content has changed and deal with that.
    for replacement <- replaced_files do
      from(f in File, where: f.id == ^replacement.file_id)
      |> Repo.update_all(set: [path: replacement.to])

      Logger.info("Replaced #{replacement.from} with #{replacement.to}")
    end
  end

  defp save_batch(batch) do
    case Operations.batch_insert(batch) do
      {:ok, results} -> Operations.broadcast(:batch, results)
      {:error, step, reason, _changes} -> log_error(batch, "#{step}: #{inspect(reason)}")
    end
  rescue
    error -> log_error(batch, Exception.message(error))
  end

  defp find_or_create_artist(name, settings) do
    slug = Utils.slugify(name)

    Repo.get_by(Artist, slug: slug) ||
      Repo.insert!(%Artist{
        name: name,
        slug: slug,
        sort_name: Utils.sort_name(name, strip_prefixes: settings.strip_sort_prefixes)
      })
  end

  defp log_error(batch, reason) do
    paths = Enum.map_join(batch, "\n", & &1.path)
    Logger.error("Failed to save scanned files (#{reason}):\n#{paths}")
  end
end
