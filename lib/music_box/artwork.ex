defmodule MusicBox.Artwork do
  @moduledoc false

  alias MusicBox.Albums
  alias MusicBox.Albums.Album
  alias MusicBox.Artwork.Fetcher
  alias MusicBox.Repo
  alias MusicBox.Tool

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

  @spec find(Album.t()) :: Repo.result(Albums.Artwork.t()) | {:error, Fetcher.find_error()}
  def find(%Album{} = album) do
    album = Repo.preload(album, [:artwork])

    case album do
      %{artwork: %{path: path}} when is_binary(path) -> {:ok, album.artwork}
      _ -> find_and_update(album)
    end
  end

  defp find_and_update(album) do
    case get_next_fetcher(album) do
      {:ok, fetcher} ->
        case fetcher_module(fetcher).find(album) do
          {:ok, path} -> update_album(album, %{fetcher: fetcher, path: path})
          {:error, :skip} -> update_and_skip(album, %{fetcher: fetcher})
          {:error, :retry_later} -> update_album(album, %{})
          {:error, :not_found} -> update_album(album, %{fetcher: fetcher})
          {:error, _error} = error -> error
        end

      {:error, _error} = error ->
        error
    end
  end

  defp get_next_fetcher(album) do
    available_fetchers = Albums.Artwork.fetchers()

    next_fetcher =
      case album do
        %{artwork: %{fetcher: fetcher}} ->
          fetcher_index = Enum.find_index(available_fetchers, &(&1 == fetcher))
          Enum.at(available_fetchers, fetcher_index + 1)

        _ ->
          List.first(available_fetchers)
      end

    case next_fetcher do
      nil -> {:error, :no_more_fetchers}
      _ -> {:ok, next_fetcher}
    end
  end

  defp fetcher_module(fetcher) do
    fetcher_module = Macro.camelize(to_string(fetcher))
    fetcher_module = Module.safe_concat(MusicBox.Artwork.Fetcher, fetcher_module)
    fetcher_module
  end

  defp update_and_skip(album, params) do
    case update_album(album, params) do
      {:ok, artwork} -> find_and_update(%{album | artwork: artwork})
      error -> error
    end
  end

  defp update_album(album, params) do
    params =
      case params do
        %{path: source_path} when is_binary(source_path) -> resize(album, source_path, params)
        _ -> params
      end

    Albums.update_artwork(
      album,
      Map.merge(params, %{
        last_fetch_attempt: DateTime.utc_now()
      })
    )
    |> tap(&broadcast/1)
  end

  defp resize(album, source_path, params) do
    variants =
      for {variant, size} <- @variants,
          do: {variant_path(album.id, variant), size}

    result = Tool.resize_artwork(%{album: album, path: source_path, variants: variants})
    File.rm(source_path)

    case result do
      {:ok, %{width: width, height: height}} ->
        Map.merge(params, %{
          path: artwork_dir(album.id),
          width: width,
          height: height
        })

      # Resizing failed so we should not store a path for this album.
      {:error, _} ->
        Map.delete(params, :path)
    end
  end

  defp broadcast({:ok, %{path: path} = artwork}) when not is_nil(path) do
    MusicBoxWeb.Endpoint.broadcast!("library:sync", "processed", %{albums: [artwork.album_id]})
  end

  defp broadcast(_error_or_no_art), do: :noop
end
