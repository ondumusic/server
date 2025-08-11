defmodule MusicBox.Artists do
  import Ecto.Query, warn: false
  alias MusicBox.Repo

  alias MusicBox.Artists.Artist

  def paginate_artists(params) do
    from(a in Artist,
      inner_join: al in assoc(a, :albums),
      order_by: [asc: a.name],
      group_by: a.id,
      select: %{a | album_count: count(al.id)}
    )
    |> Repo.paginate(params, default_limit: 100)
  end

  def get_artist!(id_or_slug) do
    from(a in Artist,
      left_join: al in assoc(a, :albums),
      order_by: [asc: a.name],
      where: a.id == ^id_or_slug or a.slug == ^id_or_slug,
      group_by: a.id,
      select: %{a | album_count: count(al.id)}
    )
    |> Repo.one!()
  end
end
