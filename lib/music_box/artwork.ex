defmodule MusicBox.Artwork do
  alias MusicBox.Albums.Album
  alias MusicBox.Albums
  alias MusicBox.Repo

  def find(%Album{} = album) do
    album = Repo.preload(album, [:artwork])

    case album do
      %{artwork: %{path: path}} when is_binary(path) -> {:ok, album}
      _ -> find_and_update(album)
    end
  end

  defp find_and_update(album) do
    case get_next_fetcher(album) do
      {:ok, fetcher} ->
        case fetcher_module(fetcher).find(album) do
          {:ok, path} -> update_album(album, fetcher, path)
          {:error, :not_found} -> update_album(album, fetcher, nil)
          {:error, _error} = error -> error
        end

      {:error, _error} = error ->
        error
    end
  end

  defp get_next_fetcher(album) do
    available_fetchers = MusicBox.Albums.Artwork.fetchers()

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

  defp update_album(album, fetcher, path) do
    Albums.update_artwork(album, %{
      path: path,
      fetcher: fetcher,
      last_fetch_attempt: DateTime.utc_now()
    })
  end
end
