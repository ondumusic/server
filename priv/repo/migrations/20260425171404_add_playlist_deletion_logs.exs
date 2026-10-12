defmodule Ondu.Repo.Migrations.AddPlaylistDeletionLogs do
  use Ecto.Migration

  def up do
    execute """
    create trigger playlists_delete
    after delete on playlists
    begin
      insert into deletion_log (entity_type, entity_id, metadata, deleted_at)
      values (
        'playlist',
        OLD.id,
        null,
        strftime('%Y-%m-%dT%H:%M:%SZ', 'now')
      );
    end;
    """

    execute """
    create trigger playlist_items_delete
    after delete on playlist_items
    begin
      insert into deletion_log (entity_type, entity_id, metadata, deleted_at)
      values (
        'playlist_item',
        OLD.id,
        null,
        strftime('%Y-%m-%dT%H:%M:%SZ', 'now')
      );
    end;
    """
  end

  def down do
    execute "drop trigger if exists playlists_delete"
    execute "drop trigger if exists playlist_items_delete"
  end
end
