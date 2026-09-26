defmodule MusicBox.Issues do
  @moduledoc """
  This module identifies albums and tracks that have missing or bad metadata, so
  we can inform the user and they can fix it at the source as MusicBox is read-only.
  """

  alias MusicBox.Albums.Album
  alias MusicBox.Issues.{IndexForm, Query, Rules}
  alias MusicBox.Repo
  alias MusicBox.Tracks.Track

  @type entry ::
          %{type: :album, id: Ecto.UUID.t(), album: Album.t(), issues: [Rules.issue()]}
          | %{type: :track, id: Ecto.UUID.t(), track: Track.t(), issues: [Rules.issue()]}

  @page_size 50

  @spec codes() :: [Rules.code()]
  defdelegate codes, to: Rules

  @spec list(map()) :: Repo.page(entry())
  def list(params \\ %{}) do
    form = IndexForm.new(%IndexForm{}, params)

    find_entries(form.code)
    |> paginate(form.page)
    |> load_page()
  end

  defp find_entries(code) do
    [
      album_entries(),
      track_number_entries(),
      untitled_track_entries(),
      orphaned_track_entries()
    ]
    |> Enum.concat()
    |> merge_entries(code)
    |> sort_entries()
  end

  defp album_entries do
    Query.albums_with_artwork()
    |> Repo.all()
    |> Enum.map(&build_entry(:album, &1.id, Rules.album(&1)))
  end

  defp track_number_entries do
    Query.albums_with_track_number_problems()
    |> Repo.all()
    |> Query.track_numbers()
    |> Repo.all()
    |> Enum.group_by(& &1.album_id)
    |> Enum.map(fn {album_id, tracks} ->
      build_entry(:album, album_id, Rules.track_numbers(tracks))
    end)
  end

  defp untitled_track_entries do
    Query.tracks_without_title()
    |> Repo.all()
    |> Enum.group_by(fn {album_id, _id} -> album_id end, fn {_album_id, id} -> id end)
    |> Enum.map(fn {album_id, track_ids} ->
      build_entry(:album, album_id, Rules.untitled_tracks(track_ids))
    end)
  end

  defp orphaned_track_entries do
    Query.orphaned_tracks()
    |> Repo.all()
    |> Enum.map(&build_entry(:track, &1.id, Rules.orphaned_track(&1)))
  end

  defp build_entry(type, id, issues), do: %{type: type, id: id, issues: issues}

  defp merge_entries(entries, code) do
    entries
    |> Enum.group_by(&{&1.type, &1.id}, & &1.issues)
    |> Enum.map(fn {{type, id}, issues} ->
      issues =
        issues
        |> Enum.concat()
        |> Enum.filter(&(code in [nil, &1.code]))
        |> sort_issues()

      build_entry(type, id, issues)
    end)
    |> Enum.reject(&(&1.issues == []))
  end

  # Issues are sorted in the order of `Rules.codes/0`, per disc where relevant.
  defp sort_issues(issues) do
    order = Rules.codes() |> Enum.with_index() |> Map.new()
    Enum.sort_by(issues, &{order[&1.code], &1.details[:disc]})
  end

  # Orphaned tracks come first as they are not visible anywhere else, then it
  # will sort the rest by default album sorting rules.
  defp sort_entries(entries) do
    {albums, tracks} = Enum.split_with(entries, &(&1.type == :album))

    sort_by_query(tracks, &Query.sorted_track_ids/1) ++
      sort_by_query(albums, &Query.sorted_album_ids/1)
  end

  defp sort_by_query(entries, sorted_ids_query) do
    by_id = Map.new(entries, &{&1.id, &1})

    entries
    |> ids()
    |> sorted_ids_query.()
    |> Repo.all()
    |> Enum.map(&Map.fetch!(by_id, &1))
  end

  defp paginate(entries, page_number) do
    total_entries = length(entries)

    %{
      entries: Enum.slice(entries, (page_number - 1) * @page_size, @page_size),
      page_number: page_number,
      page_size: @page_size,
      total_entries: total_entries,
      total_pages: ceil(total_entries / @page_size)
    }
  end

  defp load_page(%{entries: entries} = page) do
    {albums, tracks} = Enum.split_with(entries, &(&1.type == :album))
    albums = albums |> ids() |> Query.albums() |> Repo.all() |> Map.new(&{&1.id, &1})
    tracks = tracks |> ids() |> Query.tracks() |> Repo.all() |> Map.new(&{&1.id, &1})

    entries =
      Enum.map(entries, fn
        %{type: :album, id: id} = entry -> Map.put(entry, :album, albums[id])
        %{type: :track, id: id} = entry -> Map.put(entry, :track, tracks[id])
      end)

    %{page | entries: entries}
  end

  defp ids(entries), do: Enum.map(entries, & &1.id)
end
