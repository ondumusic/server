defmodule MusicBox.Artwork.Fetcher.MusicBrainz do
  use MusicBox.Artwork.Fetcher
  alias MusicBox.Repo

  @endpoint "https://musicbrainz.org/ws/2/release/"

  def find(album) do
    album = Repo.preload(album, [:artist])

    with {:ok, %{"id" => mbid}} <- find_release(album),
         {:ok, bytes} <- find_artwork(mbid) do
      save_artwork(album, bytes)
    else
      _ -> {:error, :not_found}
    end
  end

  defp find_release(album) do
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
      limit: 1,
      query: to_query(search)
    }

    query = "fmt=#{params.fmt}&limit=1&query=#{params.query}"

    uri = URI.parse(@endpoint)
    uri = %{uri | query: query}

    with {:ok, %{status: 200, body: %{} = body}} <- Req.get(uri),
         [release | _] <- Map.get(body, "releases", []) do
      {:ok, release}
    else
      _ -> {:error, :not_found}
    end
  end

  defp find_artwork(mbid) do
    archive_url = "http://coverartarchive.org/release/" <> mbid <> "/front-500"

    case Req.get(archive_url, max_redirects: 3) do
      {:ok, %{status: 200, body: bytes}} -> {:ok, bytes}
      _ -> {:error, :not_found}
    end
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
  @escape_chars [
    "+",
    "-",
    "&",
    "|",
    "!",
    "(",
    ")",
    "{",
    "}",
    "[",
    "]",
    "^",
    "\"",
    "~",
    "*",
    "?",
    ":",
    "\\"
  ]
  defp escape(input) when is_binary(input) do
    @escape_chars
    |> Enum.reduce(input, fn char, acc ->
      String.replace(acc, char, " ")
    end)
    |> String.split(~r/\s+/)
    |> Enum.map(&URI.encode/1)
    |> Enum.map(&("+" <> &1))
    |> Enum.join(" ")
  end
end
