defmodule MusicBox.Issues.Query do
  @moduledoc false

  import Ecto.Query

  alias MusicBox.Albums.Album
  alias MusicBox.Tracks.Track

  def albums_with_artwork do
    from(al in Album,
      left_join: aw in assoc(al, :artwork),
      select: %{
        id: al.id,
        release_year: al.release_year,
        is_unknown: al.is_unknown,
        artwork_hash: aw.hash,
        artwork_fetcher: aw.fetcher,
        artwork_width: aw.width,
        artwork_height: aw.height
      }
    )
  end

  def albums_with_track_number_problems do
    from(t in visible_tracks(),
      group_by: [t.album_id, fragment("coalesce(?, 1)", t.disc)],
      having:
        count(t.number) < count() or
          count(t.number, :distinct) < count(t.number) or
          max(t.number) > count(t.number, :distinct),
      distinct: true,
      select: t.album_id
    )
  end

  def track_numbers(album_ids) do
    from(t in visible_tracks(),
      where: t.album_id in ^album_ids,
      select: %{
        id: t.id,
        album_id: t.album_id,
        disc: fragment("coalesce(?, 1)", t.disc),
        number: t.number
      }
    )
  end

  def tracks_without_title do
    from(t in visible_tracks(),
      join: f in assoc(t, :file),
      where: fragment("json_extract(?, '$.title') IS NULL", f.metadata),
      select: {t.album_id, t.id}
    )
  end

  def orphaned_tracks do
    from(t in Track,
      join: f in assoc(t, :file),
      where: is_nil(t.artist_id) or is_nil(t.album_id),
      select: %{
        id: t.id,
        artist_id: t.artist_id,
        album_id: t.album_id,
        title_missing: type(fragment("json_extract(?, '$.title') IS NULL", f.metadata), :boolean)
      }
    )
  end

  def sorted_track_ids(track_ids) do
    from(t in Track,
      join: f in assoc(t, :file),
      where: t.id in ^track_ids,
      order_by: [asc: f.path],
      select: t.id
    )
  end

  def sorted_album_ids(album_ids) do
    from(al in Album,
      join: a in assoc(al, :artist),
      where: al.id in ^album_ids,
      order_by: [asc: a.sort_name, desc_nulls_last: al.release_year, asc: al.sort_name],
      select: al.id
    )
  end

  def albums(album_ids) do
    from(al in Album, where: al.id in ^album_ids, preload: [:artwork, artist: :artwork])
  end

  def tracks(track_ids) do
    from(t in Track, where: t.id in ^track_ids, preload: [:file])
  end

  defp visible_tracks do
    from(t in Track, where: not is_nil(t.album_id) and not is_nil(t.artist_id))
  end
end
