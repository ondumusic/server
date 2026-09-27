defmodule MusicBox.Artwork do
  @moduledoc false

  alias MusicBox.Albums
  alias MusicBox.Albums.Album
  alias MusicBox.Artwork.Fetcher
  alias MusicBox.Repo
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
    album = Repo.preload(album, [:artwork])

    case album do
      %{artwork: %{path: path, hash: hash}} when is_binary(path) and is_binary(hash) ->
        {:ok, album.artwork}

      _ ->
        find_and_update(album)
    end
  end

  defp find_and_update(album) do
    fetchers = Albums.Artwork.fetchers()

    params =
      case find_artwork(album, fetchers) do
        {:ok, fetcher, params} -> Map.put(params, :fetcher, fetcher)
        :not_found -> %{fetcher: List.last(fetchers)}
      end

    Repo.transact(fn -> store(album, params) end)
    |> tap(&broadcast/1)
  end

  defp store(album, params) do
    params = Map.put(params, :last_fetch_attempt, DateTime.utc_now())

    with {:ok, artwork} <- Albums.update_artwork(album, params) do
      if changed?(album.artwork, artwork), do: touch_album(album)
      {:ok, artwork}
    end
  end

  defp changed?(%Albums.Artwork{path: path, hash: hash}, %{path: path, hash: hash}), do: false
  defp changed?(nil, %{path: nil}), do: false
  defp changed?(_old_artwork, _new_artwork), do: true

  # We'll bump the album updated_at so they will be updated with the next
  # client sync and return with the new artwork.
  defp touch_album(album) do
    from(al in Album, where: al.id == ^album.id)
    |> Repo.update_all(set: [updated_at: DateTime.utc_now(:second)])
  end

  defp find_artwork(_album, []), do: :not_found

  defp find_artwork(album, [fetcher | fetchers]) do
    with {:ok, source_path} <- fetcher_module(fetcher).find(album),
         {:ok, params} <- resize(album, source_path) do
      {:ok, fetcher, params}
    else
      {:error, _reason} -> find_artwork(album, fetchers)
    end
  end

  defp fetcher_module(fetcher) do
    Module.safe_concat(Fetcher, Macro.camelize(to_string(fetcher)))
  end

  defp resize(album, source_path) do
    variants =
      for {variant, size} <- @variants,
          do: {variant_path(album.id, variant), size}

    result =
      with {:ok, hash} <- calculate_hash(source_path),
           {:ok, %{width: width, height: height}} <-
             Tool.resize_artwork(%{album: album, path: source_path, variants: variants}) do
        {:ok, %{path: artwork_dir(album.id), hash: hash, width: width, height: height}}
      end

    File.rm(source_path)
    result
  end

  defp calculate_hash(source_path) do
    with {:ok, bytes} <- File.read(source_path) do
      hash = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
      {:ok, binary_part(hash, 0, 16)}
    end
  end

  defp broadcast({:ok, %{path: path} = artwork}) when not is_nil(path) do
    MusicBoxWeb.Endpoint.broadcast!("library:sync", "processed", %{albums: [artwork.album_id]})
  end

  defp broadcast(_other), do: :noop
end
