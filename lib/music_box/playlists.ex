defmodule MusicBox.Playlists do
  @moduledoc false

  import Ecto.Query, warn: false
  alias MusicBox.Repo

  alias MusicBox.Playlists.{Playlist, PlaylistItem}

  @spec paginate_playlists(map()) :: Repo.page(Playlist)
  def paginate_playlists(params) do
    Playlist.preloaded()
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
