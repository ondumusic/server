defmodule OnduWeb.PlaylistController do
  use OnduWeb, :controller

  alias Ondu.Playlists

  plug :assign_playlist
       when action in [
              :playlist,
              :playlist_items,
              :update_playlist,
              :delete_playlist,
              :update_playlist_items
            ]

  tags ["Playlists"]

  operation :playlists,
    summary: "List playlists",
    parameters:
      Schemas.Page.params() ++
        [
          parent_id: [in: :query, type: Schemas.PlaylistId, required: false]
        ],
    responses: [
      ok: {"Returns a paginated list of playlists", "application/json", Schemas.PlaylistPage},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error}
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
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error},
      not_found: {"Playlist not found.", "application/json", Schemas.Error}
    ]

  def playlist(conn, _params) do
    render(conn, :playlist, playlist: conn.assigns.playlist)
  end

  operation :playlist_items,
    summary: "List playlist items",
    parameters:
      Schemas.Page.params() ++
        [
          playlist_id: [in: :path, type: Schemas.PlaylistId, required: true]
        ],
    responses: [
      ok:
        {"Returns a list of items for the given playlist.", "application/json",
         Schemas.PlaylistItemPage},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error},
      not_found: {"Playlist not found.", "application/json", Schemas.Error}
    ]

  def playlist_items(conn, params) do
    page = Playlists.paginate_playlists_items(conn.assigns.playlist, params)
    render(conn, :playlist_items, page: page)
  end

  operation :create_playlist,
    summary: "Create playlist",
    request_body: {"Playlist params", "application/json", Schemas.CreatePlaylistRequest},
    responses: [
      created: {"Successfully created a new playlist.", "application/json", Schemas.Playlist},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error},
      unprocessable_entity:
        {"Validation failed.", "application/json", Schemas.CreatePlaylistError}
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
      ok: {"Successfully updated the playlist.", "application/json", Schemas.Playlist},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error},
      not_found: {"Playlist not found.", "application/json", Schemas.Error},
      unprocessable_entity:
        {"Validation failed.", "application/json", Schemas.UpdatePlaylistError}
    ]

  def update_playlist(conn, params) do
    case Playlists.update_playlist(conn.assigns.playlist, params) do
      {:ok, playlist} ->
        OnduWeb.Endpoint.broadcast("library:sync", "processed", %{playlists: [playlist.id]})
        render(conn, :playlist, playlist: playlist)

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
      no_content: %OpenApiSpex.Response{
        description: "Successfully deleted the playlist."
      },
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error},
      not_found: {"Playlist not found.", "application/json", Schemas.Error}
    ]

  def delete_playlist(conn, _params) do
    case Playlists.delete_playlist(conn.assigns.playlist) do
      {:ok, playlist} ->
        deleted = [
          %{entityType: "playlistItem", entityId: playlist.id}
        ]

        OnduWeb.Endpoint.broadcast("library:sync", "deleted", %{
          deletions: deleted
        })

        send_resp(conn, :no_content, "")

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:changeset, changeset: changeset)
    end
  end

  operation :update_playlist_items,
    summary: "Update playlist items",
    parameters: [
      playlist_id: [in: :path, type: Schemas.PlaylistId, required: true]
    ],
    request_body: {"Operations", "application/json", Schemas.UpdatePlaylistItemsRequest},
    responses: [
      ok:
        {"Successfully updated the playlist items.", "application/json",
         Schemas.UpdatePlaylistItemsResponse},
      unauthorized: {"Invalid authentication.", "application/json", Schemas.Error},
      not_found: {"Playlist not found.", "application/json", Schemas.Error},
      unprocessable_entity:
        {"Validation failed.", "application/json", Schemas.UpdatePlaylistItemsError}
    ]

  def update_playlist_items(conn, params) do
    case Playlists.update_playlist_items(conn.assigns.playlist, params) do
      {:ok, changes} ->
        render(conn, :batch_result, changes: changes)

      {:error, error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:batch_error, error: error)
    end
  end

  defp assign_playlist(conn, _opts) do
    playlist_id = Map.get(conn.params, "playlist_id", "")
    playlist = Playlists.get_playlist!(playlist_id)

    conn
    |> assign(:playlist, playlist)
  end
end
