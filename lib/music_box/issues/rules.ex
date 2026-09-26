defmodule MusicBox.Issues.Rules do
  @moduledoc false

  alias MusicBox.Albums.Artwork

  @type code ::
          :artwork_missing
          | :artwork_not_square
          | :artwork_low_res
          | :album_missing
          | :release_year_missing
          | :track_number_missing
          | :track_number_duplicate
          | :track_number_gap
          | :title_missing
          | :artist_missing

  @type issue :: %{code: code(), details: map()}

  # The issues of an album or track are sorted in this order.
  @codes ~w(
    artwork_missing
    artwork_not_square
    artwork_low_res
    album_missing
    release_year_missing
    track_number_missing
    track_number_duplicate
    track_number_gap
    title_missing
    artist_missing
  )a

  # Longest side (in pixels) below which artwork is considered low resolution.
  @min_artwork_size 500

  # Artwork is only missing once all fetchers have been tried.
  @last_fetcher List.last(Artwork.fetchers())

  @spec codes() :: [code()]
  def codes, do: @codes

  @spec album(map()) :: [issue()]
  def album(album) do
    release_year(album) ++ unknown_album(album) ++ artwork(album)
  end

  defp release_year(%{release_year: nil}), do: [issue(:release_year_missing)]
  defp release_year(_album), do: []

  defp unknown_album(%{is_unknown: true}), do: [issue(:album_missing)]
  defp unknown_album(_album), do: []

  defp artwork(%{artwork_path: nil, artwork_fetcher: @last_fetcher}),
    do: [issue(:artwork_missing)]

  defp artwork(%{artwork_path: path, artwork_width: width, artwork_height: height})
       when is_binary(path) and is_integer(width) and is_integer(height) do
    dimensions = %{width: width, height: height}
    not_square(dimensions) ++ low_res(dimensions)
  end

  defp artwork(_album), do: []

  defp low_res(%{width: width, height: height} = dimensions) do
    if max(width, height) < @min_artwork_size,
      do: [issue(:artwork_low_res, dimensions)],
      else: []
  end

  defp not_square(%{width: width, height: height} = dimensions) do
    if width != height,
      do: [issue(:artwork_not_square, dimensions)],
      else: []
  end

  @spec track_numbers([map()]) :: [issue()]
  def track_numbers(tracks) do
    {unnumbered, numbered} = Enum.split_with(tracks, &is_nil(&1.number))

    per_disc =
      numbered
      |> Enum.group_by(& &1.disc, & &1.number)
      |> Enum.sort()
      |> Enum.flat_map(fn {disc, numbers} ->
        duplicate_numbers(disc, numbers) ++ number_gaps(disc, numbers)
      end)

    missing_numbers(unnumbered) ++ per_disc
  end

  defp missing_numbers([]), do: []

  defp missing_numbers(tracks),
    do: [issue(:track_number_missing, %{track_ids: Enum.map(tracks, & &1.id)})]

  defp duplicate_numbers(disc, numbers) do
    duplicates =
      for {number, count} <- Enum.frequencies(numbers), count > 1, do: number

    if duplicates != [],
      do: [issue(:track_number_duplicate, %{disc: disc, numbers: Enum.sort(duplicates)})],
      else: []
  end

  defp number_gaps(disc, numbers) do
    gaps = Enum.to_list(1..Enum.max(numbers)//1) -- numbers

    if gaps != [],
      do: [issue(:track_number_gap, %{disc: disc, numbers: gaps})],
      else: []
  end

  @spec untitled_tracks([Ecto.UUID.t()]) :: [issue()]
  def untitled_tracks([]), do: []
  def untitled_tracks(track_ids), do: [issue(:title_missing, %{track_ids: track_ids})]

  @spec orphaned_track(map()) :: [issue()]
  def orphaned_track(%{artist_id: nil} = track), do: [issue(:artist_missing) | title(track)]
  def orphaned_track(%{album_id: nil} = track), do: [issue(:album_missing) | title(track)]
  def orphaned_track(_track), do: []

  defp title(%{title_missing: true}), do: [issue(:title_missing)]
  defp title(_track), do: []

  defp issue(code, details \\ %{}), do: %{code: code, details: details}
end
