defmodule MusicBox.Tracks.Query do
  import Ecto.Query

  alias MusicBox.Tracks.Track
  alias MusicBox.Tracks.IndexForm, as: F

  def paginate_tracks(%F{} = form) do
    Track.preloaded()
    |> where_artist(form)
    |> where_album(form)
    |> set_order_by(form)
  end

  defp where_artist(query, %{artist_id: nil}), do: query

  defp where_artist(query, %{artist_id: artist_id}) do
    where(query, [track: t, album: al], t.artist_id == ^artist_id or al.artist_id == ^artist_id)
  end

  defp where_album(query, %{album_id: nil}), do: query

  defp where_album(query, %{album_id: album_id}) do
    where(query, [track: t], t.album_id == ^album_id)
  end

  defp set_order_by(query, %F{sort_by: :random, random_seed: seed}) when not is_nil(seed) do
    order_by(
      query,
      [track: t],
      fragment("(((? * 2654435761) + ?) % 2147483647)", t.rowid, ^seed)
    )
  end

  defp set_order_by(query, _form) do
    order_by(query, [album: al, artist: a],
      asc: a.name,
      desc_nulls_last: al.release_year,
      asc: al.name
    )
  end
end
