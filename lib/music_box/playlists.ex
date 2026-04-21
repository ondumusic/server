defmodule MusicBox.Playlists do
  @moduledoc false

  import Ecto.Query, warn: false
  alias MusicBox.Repo

  alias MusicBox.Playlists.Playlist

  @spec paginate_playlists(map()) :: Repo.page(Playlist)
  def paginate_playlists(params) do
    Playlist.preloaded()
    |> order_by([playlist: p], asc: p.name)
    |> Repo.paginate(params, default_limit: 100)
  end

  @spec get_playlist!(Ecto.UUID.t()) :: Playlist.t()
  def get_playlist!(playlist_id) do
    Playlist.preloaded()
    |> where([playlist: p], p.id == ^playlist_id)
    |> Repo.one!()
  end
end
