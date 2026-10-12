defmodule OnduWeb.IssueJSON do
  use OnduWeb, :json

  alias OnduWeb.LibraryJSON

  def issues(%{page: page}) do
    %{
      __type: "page",
      __subtype: "issues",
      pageNumber: page.page_number,
      pageSize: page.page_size,
      totalEntries: page.total_entries,
      totalPages: page.total_pages,
      entries: Enum.map(page.entries, &entry/1)
    }
  end

  defp entry(%{type: :album, album: album, issues: issues}) do
    %{
      __type: "albumIssues",
      album: LibraryJSON.album(%{album: album, render_tracks: false}),
      artist: LibraryJSON.artist(%{artist: album.artist}),
      issues: Enum.map(issues, &issue/1)
    }
  end

  defp entry(%{type: :track, track: track, issues: issues}) do
    %{
      __type: "trackIssues",
      track: %{id: track.id, name: track.name, path: track.file.path},
      issues: Enum.map(issues, &issue/1)
    }
  end

  defp issue(%{code: code, details: details}) do
    %{
      code: code,
      details:
        Map.new(details, fn
          {:track_ids, track_ids} -> {:trackIds, track_ids}
          {key, value} -> {key, value}
        end)
    }
  end
end
