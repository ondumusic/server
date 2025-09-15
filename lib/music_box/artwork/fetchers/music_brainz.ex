defmodule MusicBox.Artwork.Fetcher.MusicBrainz do
  use MusicBox.Artwork.Fetcher
  alias MusicBox.Repo

  @endpoint "https://musicbrainz.org/ws/2/release/"

  def find(album) do
    album = Repo.preload(album, [:artist])

    with {:ok, releases} <- find_releases(album),
         {:ok, bytes} <- find_artwork(releases) do
      save_artwork(album, bytes)
    else
      _ -> {:error, :not_found}
    end
  end

  defp find_releases(album) do
    search = %{
      artist: album.artist.name,
      release: album.name
    }

    search =
      if album.release_year,
        do: Map.put(search, :date, to_string(album.release_year)),
        else: search

    params = %{
      fmt: :json,
      limit: 3,
      query: to_query(search)
    }

    uri = URI.parse(@endpoint)
    uri = %{uri | query: params_to_query(params)}

    with {:ok, %{status: 200, body: %{} = body}} <- Req.get(uri),
         [_ | _] = releases <- Map.get(body, "releases", []) do
      {:ok, releases}
    else
      _ -> {:error, :not_found}
    end
  end

  defp find_artwork([]), do: {:error, :not_found}

  defp find_artwork([%{"id" => mbid} | releases]) do
    archive_url = "http://coverartarchive.org/release/" <> mbid <> "/front-500"

    case Req.get(archive_url, max_redirects: 3) do
      {:ok, %{status: 200, body: bytes}} -> {:ok, bytes}
      _ -> find_artwork(releases)
    end
  end

  defp params_to_query(%{} = params) do
    params
    |> Enum.map(fn {k, v} ->
      to_string(k) <> "=" <> to_string(v)
    end)
    |> Enum.join("&")
  end

  defp to_query(%{} = map) do
    map
    |> Enum.map(fn {field, query} ->
      "#{field}:(#{escape(query)})"
    end)
    |> Enum.join(" AND ")
    |> String.replace(" ", "%20")
  end

  # https://lucene.apache.org/core/2_9_4/queryparsersyntax.html#Escaping%20Special%20Characters
  @escape_chars_regex ~r/([+\-&|!(){}[\]^"~*?:\\])/
  def escape(input) when is_binary(input) do
    input
    |> String.replace(@escape_chars_regex, "\\\\\\1")
    |> String.split(~r/\s+/)
    |> Enum.map(&URI.encode/1)
    |> Enum.map(&("+" <> &1))
    |> Enum.join(" ")
  end
end
