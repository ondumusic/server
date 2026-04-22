defmodule MusicBoxWeb.PlaylistController do
  use MusicBoxWeb, :controller

  alias MusicBox.Playlists

  plug :assign_playlist
       when action in [
              :playlist,
              :playlist_items,
              :playlist_item,
              :update_playlist,
              :delete_playlist,
              :update_playlist_items
            ]

  plug :assign_playlist_item when action in [:playlist_item]

  operation :playlists,
    summary: "List playlists",
    responses: [
      ok: {"Playlists", "application/json", Schemas.PlaylistPage},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]

  def playlists(conn, params) do
    render(conn, :playlists, page: Playlists.paginate_playlists(params))
  end

  operation :playlist,
    summary: "Get a specific playlist",
    parameters: [
      playlist_id: [in: :path, type: Schemas.PlaylistId, required: true]
    ],
    responses: [
      ok: {"Playlist", "application/json", Schemas.Playlist},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error}
    ]

  def playlist(conn, _params) do
    render(conn, :playlist, playlist: conn.assigns.playlist)
  end

  operation :playlist_items,
    summary: "List playlist items",
    parameters: [
      playlist_id: [in: :path, type: Schemas.PlaylistId, required: true]
    ],
    responses: [
      ok: {"Playlist Items", "application/json", Schemas.PlaylistItemPage},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error}
    ]

  def playlist_items(conn, params) do
    page = Playlists.paginate_playlists_items(conn.assigns.playlist, params)
    render(conn, :playlist_items, page: page)
  end

  operation :playlist_item,
    summary: "Get a specific playlist item",
    parameters: [
      playlist_id: [in: :path, type: Schemas.PlaylistId, required: true],
      playlist_item_id: [in: :path, type: Schemas.PlaylistItemId, required: true]
    ],
    responses: [
      ok: {"Playlist Item", "application/json", Schemas.PlaylistItem},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error}
    ]

  def playlist_item(conn, _params) do
    render(conn, :playlist_item, playlist_item: conn.assigns.playlist_item)
  end

  operation :create_playlist,
    summary: "Create playlist",
    request_body: {"Playlist params", "application/json", Schemas.CreatePlaylistRequest},
    responses: [
      created: {"Playlist", "application/json", Schemas.Playlist},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      unprocessable_entity: {"Validation Error", "application/json", Schemas.CreatePlaylistError}
    ]

  def create_playlist(conn, params) do
    case Playlists.create_playlist(params) do
      {:ok, playlist} ->
        conn
        |> put_status(:created)
        |> render(:playlist, playlist: playlist)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:changeset, changeset: changeset)
    end
  end

  operation :update_playlist,
    summary: "Update playlist",
    parameters: [
      playlist_id: [in: :path, type: Schemas.PlaylistId, required: true]
    ],
    request_body: {"Playlist params", "application/json", Schemas.UpdatePlaylistRequest},
    responses: [
      ok: {"Playlist", "application/json", Schemas.Playlist},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error},
      unprocessable_entity: {"Validation Error", "application/json", Schemas.UpdatePlaylistError}
    ]

  def update_playlist(conn, params) do
    case Playlists.update_playlist(conn.assigns.playlist, params) do
      {:ok, playlist} ->
        conn
        |> render(:playlist, playlist: playlist)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:changeset, changeset: changeset)
    end
  end

  operation :delete_playlist,
    summary: "Delete playlist",
    parameters: [
      playlist_id: [in: :path, type: Schemas.PlaylistId, required: true]
    ],
    responses: [
      ok: {"Playlist", "application/json", Schemas.Playlist},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error},
      unprocessable_entity: {"Validation Error", "application/json", Schemas.DeletePlaylistError}
    ]

  def delete_playlist(conn, _params) do
    case Playlists.delete_playlist(conn.assigns.playlist) do
      {:ok, playlist} ->
        conn
        |> render(:playlist, playlist: playlist)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:changeset, changeset: changeset)
    end
  end

  def update_playlist_items(conn, params) do
    case Playlists.update_playlist_items(conn.assigns.playlist, params) do
      {:ok, changes} ->
        render(conn, :batch_result, changes: changes)

      {:error, error} ->
        conn
        |> put_status(:bad_request)
        |> render(:batch_error, error: error)
    end
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
