defmodule MusicBox.Artwork do
  @moduledoc false

  alias MusicBox.Albums
  alias MusicBox.Albums.Album
  alias MusicBox.Artwork.Fetcher
  alias MusicBox.Repo
  alias MusicBox.Tool

  require Logger

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
    if path = Map.get(params, :path),
      do: Tool.resize_artwork(%{album: album, path: path})

    Albums.update_artwork(
      album,
      Map.merge(params, %{
        last_fetch_attempt: DateTime.utc_now()
      })
    )
    |> tap(&broadcast/1)
  end

  defp broadcast({:ok, %{path: path} = artwork}) when not is_nil(path) do
    MusicBoxWeb.Endpoint.broadcast!("library:updated", "processed", %{albums: [artwork.album_id]})
  end

  defp broadcast(_error_or_no_art), do: :noop
end
