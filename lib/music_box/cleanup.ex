defmodule MusicBox.Cleanup do
  @moduledoc false

  alias MusicBox.Albums.Album
  alias MusicBox.Artists.Artist
  alias MusicBox.Repo
  alias MusicBox.Tracks.Track

  import Ecto.Query

  def work do
    cleanup_unused_albums()
    cleanup_unused_artists()

    update_sort_names(Artist)
    update_sort_names(Album)

    :ok
  end

  defp cleanup_unused_albums do
    known_albums_query = from(t in Track, select: t.album_id, group_by: t.album_id)

    from(al in Album,
      where: al.id not in subquery(known_albums_query)
    )
    |> Repo.delete_all()
  end

  defp cleanup_unused_artists do
    known_artists_query =
      from(t in Track, select: t.artist_id, group_by: t.artist_id)
      |> union_all(^from(al in Album, select: al.artist_id, group_by: al.artist_id))

    from(a in Artist,
      where: a.id not in subquery(known_artists_query)
    )
    |> Repo.delete_all()
  end

  @strip_prefixes ~w(the)
  defp update_sort_names(schema) do
    Repo.transact(
      fn repo ->
        schema
        |> repo.stream()
        |> Stream.each(fn entry ->
          sort_name =
            MusicBox.FileScanner.Utils.sort_name(entry.name, strip_prefixes: @strip_prefixes)

          entry
          |> Ecto.Changeset.change()
          |> Ecto.Changeset.put_change(:sort_name, sort_name)
          |> repo.update!()
        end)
        |> Stream.run()

        {:ok, nil}
      end,
      timeout: 30_000
    )
  end
end
