defmodule MusicBoxWeb.PlaylistJSON do
  use MusicBoxWeb, :json

  def playlists(%{page: page} = assigns) do
    %{
      __type: "page",
      __subtype: "playlist",
      pageNumber: page.page_number,
      pageSize: page.page_size,
      totalEntries: page.total_entries,
      totalPages: page.total_pages,
      entries: json_map(assigns, [:page, :entries], :playlist)
    }
  end

  def playlist_items(%{page: page} = assigns) do
    %{
      __type: "page",
      __subtype: "playlistItem",
      pageNumber: page.page_number,
      pageSize: page.page_size,
      totalEntries: page.total_entries,
      totalPages: page.total_pages,
      entries: json_map(assigns, [:page, :entries], :playlist_item)
    }
  end

  def playlist(%{playlist: playlist}) do
    %{
      __type: "playlist",
      id: playlist.id,
      name: playlist.name,
      trackCount: playlist.track_count,
      insertedAt: playlist.inserted_at
    }
  end

  def playlist_item(%{playlist_item: playlist_item}) do
    %{
      __type: "playlistItem",
      id: playlist_item.id,
      position: playlist_item.position,
      playlistId: playlist_item.playlist_id,
      trackId: playlist_item.track_id,
      insertedAt: playlist_item.inserted_at
    }
  end

  def changeset(%{changeset: changeset}) do
    %{
      fields: json_changeset(changeset)
    }
  end

  def batch_result(%{changes: changes}) do
    %{
      added: Enum.map(changes.added, &playlist_item(%{playlist_item: &1})),
      moved: Enum.map(changes.moved, &playlist_item(%{playlist_item: &1})),
      removed: changes.removed
    }
  end

  def batch_error(%{error: :too_many_operations}) do
    %{
      error: "too_many_operations"
    }
  end

  def batch_error(%{error: {:conflict_items, ids}}) do
    %{
      error: "move_remove_conflict",
      itemIds: ids
    }
  end

  def batch_error(%{error: {:conflict_positions, positions}}) do
    %{
      error: "add_move_conflict",
      positions: positions
    }
  end

  def batch_error(%{error: {:missing_items, ids}}) do
    %{
      error: "unknown_items",
      itemIds: ids
    }
  end

  def batch_error(%{error: {:missing_tracks, ids}}) do
    %{
      error: "unknown_tracks",
      trackIds: ids
    }
  end
end
