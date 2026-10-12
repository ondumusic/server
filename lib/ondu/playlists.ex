defmodule Ondu.Playlists do
  @moduledoc false

  import Ecto.Query, warn: false
  alias Ondu.FractionalIndex
  alias Ondu.Playlists.{Operations, Playlist, PlaylistItem}
  alias Ondu.Repo

  @spec paginate_playlists(map()) :: Repo.page(Playlist)
  def paginate_playlists(params) do
    parent_id = Map.get(params, "parent_id") || Map.get(params, :parent_id)

    query = Playlist.preloaded()

    query =
      if parent_id,
        do: where(query, [playlist: p], p.parent_id == ^parent_id),
        else: where(query, [playlist: p], is_nil(p.parent_id))

    query
    |> order_by([playlist: p], asc: p.name)
    |> Repo.paginate(params, default_limit: 100)
  end

  @spec create_playlist(map()) :: {:ok, Playlist.t()} | {:error, Ecto.Changeset.t()}
  def create_playlist(params) do
    %Playlist{}
    |> Playlist.changeset(params)
    |> Repo.insert()
  end

  @spec update_playlist(Playlist.t(), map()) :: {:ok, Playlist.t()} | {:error, Ecto.Changeset.t()}
  def update_playlist(playlist, params) do
    playlist
    |> Playlist.changeset(params)
    |> Repo.update()
  end

  @spec delete_playlist(Playlist.t()) :: {:ok, Playlist.t()} | {:error, Ecto.Changeset.t()}
  def delete_playlist(playlist) do
    playlist
    |> Repo.delete()
  end

  @spec update_playlist_items(Playlist.t(), Operations.t()) ::
          {:ok, Operations.result()} | Operations.error()
  def update_playlist_items(playlist, changes) do
    Operations.batch_update(playlist, changes)
  end

  @spec rebalance_playlist_items(Playlist.t()) :: {:ok, non_neg_integer()}
  def rebalance_playlist_items(playlist) do
    Repo.transact(fn repo ->
      item_ids =
        from(i in PlaylistItem,
          where: i.playlist_id == ^playlist.id,
          order_by: [asc: :position],
          select: i.id
        )
        |> repo.all()

      new_keys = FractionalIndex.generate_n_keys_between(nil, nil, length(item_ids))
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Enum.zip(item_ids, new_keys)
      |> Enum.each(fn {item_id, key} ->
        from(i in PlaylistItem, where: i.id == ^item_id)
        |> repo.update_all(set: [position: key, updated_at: now])
      end)

      {:ok, length(item_ids)}
    end)
  end

  @spec paginate_playlists_items(Playlist.t(), map()) :: Repo.page(PlaylistItem)
  def paginate_playlists_items(%Playlist{id: playlist_id}, params) do
    PlaylistItem.preloaded()
    |> where([playlist_item: pi], pi.playlist_id == ^playlist_id)
    |> order_by([playlist_item: pi], asc: pi.position)
    |> Repo.paginate(params, default_limit: 100)
  end

  @spec get_playlist!(Ecto.UUID.t()) :: Playlist.t()
  def get_playlist!(playlist_id) do
    Playlist.preloaded()
    |> where([playlist: p], p.id == ^playlist_id)
    |> Repo.one!()
  end

  @spec get_playlist_item!(Ecto.UUID.t()) :: PlaylistItem.t()
  def get_playlist_item!(playlist_item_id) do
    PlaylistItem.preloaded()
    |> where([playlist_item: pi], pi.id == ^playlist_item_id)
    |> Repo.one!()
  end

  @spec get_playlist_item_for_playlist!(Playlist.t(), Ecto.UUID.t()) :: PlaylistItem.t()
  def get_playlist_item_for_playlist!(%Playlist{id: playlist_id}, playlist_item_id) do
    PlaylistItem.preloaded()
    |> where([playlist_item: pi], pi.playlist_id == ^playlist_id)
    |> where([playlist_item: pi], pi.id == ^playlist_item_id)
    |> Repo.one!()
  end
end
