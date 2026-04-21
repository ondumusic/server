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
      __subtype: "playlist_item",
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
      __type: "playlist_item",
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
end
