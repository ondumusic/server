defmodule MusicBox.Artwork do
  @moduledoc false

  alias MusicBox.Albums
  alias MusicBox.Albums.Album
  alias MusicBox.Albums.CoverFile
  alias MusicBox.Artwork.Fetcher
  alias MusicBox.Repo
  alias MusicBox.Storage
  alias MusicBox.Tool

  import Ecto.Query

  @type variant :: :thumbnail | :large

  # Maximum size (in pixels) of each square variant we will generate
  # NOTE: That this will never upscale images.
  @variants [thumbnail: 128, large: 640]
  @variant_names Keyword.keys(@variants)

  @spec variants() :: [{variant(), pos_integer()}]
  def variants, do: @variants

  @spec artwork_dir(String.t()) :: String.t()
  def artwork_dir(album_id) do
    MusicBox.Config.artwork_path()
    |> Path.join(album_id)
  end

  @spec variant_path(String.t(), variant()) :: String.t()
  def variant_path(album_id, variant) when variant in @variant_names do
    album_id
    |> artwork_dir()
    |> Path.join("#{variant}.jpg")
  end

  @doc """
  Returns the actual size of each variant for artwork of the given source
  dimensions, the source is fitted within the variant size and padded to a square.
  """
  @spec variant_sizes(Albums.Artwork.t()) :: [{variant(), pos_integer()}]
  def variant_sizes(%Albums.Artwork{width: width, height: height})
      when is_integer(width) and is_integer(height) do
    for {variant, max_size} <- @variants do
      {variant, min(max(width, height), max_size)}
    end
  end

  @spec find(Album.t()) :: Repo.result(Albums.Artwork.t())
  def find(%Album{} = album) do
    album = Repo.preload(album, [:artwork, tracks: :file])
    started_at = DateTime.utc_now(:second)
    fetchers = Albums.Artwork.fetchers()
    context = find_context(album)

    params =
      case find_artwork(album, fetchers, context) do
        {:ok, fetcher, params} -> Map.put(params, :fetcher, fetcher)
        :not_found -> %{fetcher: List.last(fetchers), hash: nil, source_path: nil}
      end
      |> Map.merge(context)

    with {:ok, artwork} <-
           Repo.transact(fn -> store(album, Map.put(params, :last_fetch_attempt, started_at)) end) do
      if changed?(album.artwork, artwork) do
        artwork
        |> cleanup()
        |> broadcast()
      end

      {:ok, artwork}
    end
  end

  defp store(album, params) do
    with {:ok, artwork} <- Albums.update_artwork(album, params) do
      if changed?(album.artwork, artwork), do: touch_album(album)
      {:ok, artwork}
    end
  end

  defp changed?(%Albums.Artwork{hash: hash}, %{hash: hash}), do: false
  defp changed?(nil, %{hash: nil}), do: false
  defp changed?(_old_artwork, _new_artwork), do: true

  # We'll bump the album updated_at so they will be updated with the next
  # client sync and return with the new artwork.
  defp touch_album(album) do
    from(al in Album, where: al.id == ^album.id)
    |> Repo.update_all(set: [updated_at: DateTime.utc_now(:second)])
  end

  defp find_context(album) do
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

  defp find_artwork(_album, [], _context), do: :not_found

  defp find_artwork(album, [fetcher | fetchers], context) do
    with {:ok, result} <- fetcher_module(fetcher).find(album, context),
         {:ok, params} <- resize(album, result.unprocessed_path) do
      {:ok, fetcher, Map.put(params, :source_path, result.source_path)}
    else
      {:error, _reason} -> find_artwork(album, fetchers, context)
    end
  end

  defp fetcher_module(fetcher) do
    Module.safe_concat(Fetcher, Macro.camelize(to_string(fetcher)))
  end

  defp resize(album, source_path) do
    result =
      with {:ok, hash} <- calculate_hash(source_path) do
        case album.artwork do
          %{hash: ^hash, width: width, height: height} ->
            {:ok, %{hash: hash, width: width, height: height}}

          _artwork ->
            resize_variants(album, source_path, hash)
        end
      end

    File.rm(source_path)
    result
  end

  defp resize_variants(album, source_path, hash) do
    variants =
      for {variant, size} <- @variants,
          do: {variant_path(album.id, variant), size}

    with {:ok, %{width: width, height: height}} <-
           Tool.resize_artwork(%{album: album, path: source_path, variants: variants}) do
      {:ok, %{hash: hash, width: width, height: height}}
    end
  end

  defp calculate_hash(source_path) do
    with {:ok, bytes} <- File.read(source_path) do
      hash = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
      {:ok, binary_part(hash, 0, 16)}
    end
  end

  defp cleanup(artwork) do
    if is_nil(artwork.hash), do: File.rm_rf(artwork_dir(artwork.album_id))
    artwork
  end

  defp broadcast(artwork) do
    MusicBoxWeb.Endpoint.broadcast!("library:sync", "processed", %{albums: [artwork.album_id]})
    artwork
  end
end
