defmodule MusicBox.Counters do
  @moduledoc """
  This module is responsible for updating the *_count fields on records, e.g.
  the album count for artists, or the track count for albums/playlists.
  """

  import Ecto.Query

  alias MusicBox.Repo

  @spec update(module(), atom(), module(), atom(), :all | [Ecto.UUID.t()]) :: [Ecto.UUID.t()]
  def update(parent, counter_field, child, foreign_key, ids \\ :all) do
    counts =
      from(p in parent,
        left_join: c in ^child,
        on: field(c, ^foreign_key) == p.id,
        group_by: p.id,
        select: %{id: p.id, count: count(c.id)}
      )
      |> where_ids(ids)

    {_count, updated_ids} =
      from(p in parent,
        join: c in subquery(counts),
        on: p.id == c.id,
        where: field(p, ^counter_field) != c.count or is_nil(field(p, ^counter_field)),
        update: [set: [{^counter_field, c.count}, {:updated_at, ^DateTime.utc_now(:second)}]],
        select: p.id
      )
      |> Repo.update_all([])

    updated_ids
  end

  defp where_ids(query, :all), do: query
  defp where_ids(query, ids), do: where(query, [p], p.id in ^ids)
end
