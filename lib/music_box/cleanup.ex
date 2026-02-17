defmodule MusicBox.Cleanup do
  @moduledoc false

  alias MusicBox.Albums.Album
  alias MusicBox.Artists.Artist
  alias MusicBox.FileScanner.Utils
  alias MusicBox.Repo
  alias MusicBox.Settings
  alias MusicBox.Tracks.Track

  import Ecto.Query

  @steps ~w(sort_names unused)a

  def work(steps \\ :all) do
    settings = Settings.get()
    steps = List.wrap(steps)

    state = %{
      settings: settings
    }

    _result =
      @steps
      |> Enum.filter(fn step ->
        :all in steps or step in steps
      end)
      |> Enum.reduce(state, &exec_step/2)

    :ok
  end

  defp exec_step(:sort_names, %{settings: settings} = state) do
    update_sort_names(Artist, settings.strip_sort_prefixes)
    update_sort_names(Album, settings.strip_sort_prefixes)
    state
  end

  defp exec_step(:unused, state) do
    cleanup_unused_albums()
    cleanup_unused_artists()
    state
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

  defp update_sort_names(schema, strip_prefixes) do
    Repo.transact(
      fn repo ->
        schema
        |> repo.stream()
        |> Stream.each(fn entry ->
          sort_name = Utils.sort_name(entry.name, strip_prefixes: strip_prefixes)

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
