defmodule MusicBoxWeb.PlaylistController do
  use MusicBoxWeb, :controller

  alias MusicBox.Playlists

  plug :assign_playlist when action in [:playlist, :playlist_items, :playlist_item]
  plug :assign_playlist_item when action in [:playlist_item]

  def playlists(conn, params) do
    render(conn, :playlists, page: Playlists.paginate_playlists(params))
  end

  def playlist(conn, _params) do
    render(conn, :playlist, playlist: conn.assigns.playlist)
  end

  def playlist_items(conn, params) do
    page = Playlists.paginate_playlists_items(conn.assigns.playlist, params)
    render(conn, :playlist_items, page: page)
  end

  def playlist_item(conn, _params) do
    render(conn, :playlist_item, playlist_item: conn.assigns.playlist_item)
  end

  defp assign_playlist(conn, _opts) do
    playlist_id = Map.get(conn.params, "playlist_id", "")
    playlist = Playlists.get_playlist!(playlist_id)

    conn
    |> assign(:playlist, playlist)
  end

  defp assign_playlist_item(conn, _opts) do
    playlist_item_id = Map.get(conn.params, "playlist_item_id", "")

    playlist_item =
      if playlist = conn.assigns[:playlist],
        do: Playlists.get_playlist_item_for_playlist!(playlist, playlist_item_id),
        else: Playlists.get_playlist_item!(playlist_item_id)

    conn
    |> assign(:playlist_item, playlist_item)
  end
end
