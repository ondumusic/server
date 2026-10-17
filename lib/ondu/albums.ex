defmodule Ondu.Albums do
  @moduledoc false

  import Ecto.Query, warn: false
  alias Ondu.Repo

  alias Ondu.Albums.{Album, Artwork, CoverFile}
  alias Ondu.Artists.Artist
  alias Ondu.Artwork.Fetcher
  alias Ondu.Storage

  @spec paginate_albums(map()) :: Repo.page(Album)
  def paginate_albums(params) do
    Album.preloaded()
    |> order_by([album: al, artist: a],
      asc: a.sort_name,
      desc_nulls_last: al.release_year,
      asc: al.sort_name
    )
    |> Repo.paginate(params)
  end

  @spec paginate_albums_for_artist(Artist.t(), map()) :: Repo.page(Album)
  def paginate_albums_for_artist(%Artist{id: artist_id}, params) do
    Album.preloaded()
    |> where([album: al], al.artist_id == ^artist_id)
    |> order_by([album: al], desc_nulls_last: al.release_year, asc: al.sort_name)
    |> Repo.paginate(params)
  end

  @spec get_album!(Ecto.UUID.t()) :: Album.t()
  def get_album!(id) do
    Album.preloaded()
    |> where([album: al], al.id == ^id)
    |> Repo.one!()
  end

  @spec get_album_for_artist!(Artist.t(), String.t()) :: Album.t()
  def get_album_for_artist!(%Artist{id: artist_id}, id_or_slug) do
    Album.preloaded()
    |> where([album: al], al.artist_id == ^artist_id)
    |> where([album: al], al.id == ^id_or_slug or al.slug == ^id_or_slug)
    |> Repo.one!()
  end

  @spec update_artwork(Album.t(), map()) :: Repo.result(Artwork.t())
  def update_artwork(%Album{} = album, attrs), do: Ondu.Artwork.upsert(:albums, album, attrs)

  @doc """
  Marks the artwork of the given albums as invalidated, so the artwork fetcher
  checks again whether it needs to be replaced.
  """
  @spec invalidate_artworks([Ecto.UUID.t() | nil]) :: {:ok, non_neg_integer()}
  def invalidate_artworks(album_ids) do
    now = DateTime.utc_now(:second)

    album_ids
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.chunk_every(1_000)
    |> Enum.reduce({:ok, 0}, fn ids, {:ok, count} ->
      {updated, _} =
        from(aw in Artwork, where: aw.album_id in ^ids)
        |> Repo.update_all(set: [invalidated_at: now])

      {:ok, count + updated}
    end)
  end

  @doc """
  Compares the cover files found in a complete walk of the music path with the
  best cover file each album directory had during its last fetch attempt. Albums
  of which a cover file was added, changed or removed are invalidated.
  """
  @spec invalidate_cover_files([Storage.file_entry()]) :: {:ok, non_neg_integer()}
  def invalidate_cover_files(cover_files) do
    cover_files_by_dir = Enum.group_by(cover_files, &Path.dirname(&1.path))

    # Same as the fetcher, the cover file is found across all album directories.
    current_cover = fn dirs ->
      dirs |> Enum.flat_map(&Map.get(cover_files_by_dir, &1, [])) |> CoverFile.find()
    end

    # Find all album ids that have artwork in one of these directories
    album_ids =
      from(aw in Artwork, where: not is_nil(aw.dirs), select: {aw.album_id, aw.dirs, aw.cover})
      |> Repo.all()
      |> Enum.reject(fn {_album_id, dirs, cover} -> current_cover.(dirs) == cover end)
      |> Enum.map(fn {album_id, _dirs, _cover} -> album_id end)

    invalidate_artworks(album_ids)
  end

  @doc """
  Looks for the cover of an album in its files (cover files next to the tracks
  or artwork embedded in the tracks) and stores it as the album artwork. Not
  finding one is stored as well, so it is only looked up again when something
  changed.
  """
  @spec find_cover(Album.t()) :: Repo.result(Artwork.t())
  def find_cover(%Album{} = album) do
    album = Repo.preload(album, [:artwork, tracks: :file])
    fetchers = Artwork.fetchers()
    context = cover_context(album)
    params = Map.put(context, :last_fetch_attempt, DateTime.utc_now(:second))

    with :not_found <- find_cover(album, fetchers, context, params) do
      params = Map.merge(params, %{fetcher: List.last(fetchers), hash: nil, source_path: nil})
      Ondu.Artwork.save(:albums, album, album.artwork, params)
    end
  end

  defp find_cover(_album, [], _context, _params), do: :not_found

  # Tries the fetchers in order, also when an image was found that could not be
  # stored (e.g. it was not a valid image).
  defp find_cover(album, [fetcher | fetchers], context, params) do
    with {:ok, result} <- fetcher_module(fetcher).find(album, context),
         found = Map.merge(params, %{fetcher: fetcher, source_path: result.source_path}),
         {:ok, artwork} <- put_cover(album, result.unprocessed_path, found) do
      {:ok, artwork}
    else
      {:error, _reason} -> find_cover(album, fetchers, context, params)
    end
  end

  # The unprocessed image is removed once it was stored (or failed to).
  defp put_cover(album, path, params) do
    result = Ondu.Artwork.put(:albums, album, path, params)
    File.rm(path)
    result
  end

  defp fetcher_module(fetcher) do
    Module.safe_concat(Fetcher, Macro.camelize(to_string(fetcher)))
  end

  defp cover_context(album) do
    # Because tracks could be organised in multiple directories (for example a
    # cd1, cd2 directory) we want to check both of these.
    dirs =
      album.tracks
      |> Enum.map(&Path.dirname(&1.file.path))
      |> Enum.uniq()
      |> Enum.sort()

    cover = dirs |> Enum.flat_map(&Storage.list_dir/1) |> CoverFile.find()
    %{dirs: dirs, cover: cover}
  end
end
