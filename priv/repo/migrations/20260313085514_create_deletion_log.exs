defmodule MusicBox.Repo.Migrations.CreateDeletionLog do
  use Ecto.Migration

  def up do
    create table(:deletion_log, primary_key: false) do
      add :entity_type, :string, null: false, primary_key: true
      add :entity_id, :integer, null: false, primary_key: true
      add :metadata, :map, default: %{}
      add :deleted_at, :utc_datetime, null: false
    end

    create index(:deletion_log, [:entity_type])
    create index(:deletion_log, [:deleted_at])

    execute """
    create trigger files_delete
    after delete on files
    begin
      insert into deletion_log (entity_type, entity_id, metadata, deleted_at)
      values (
        'file',
        OLD.id,
        json_object('path', OLD.path),
        strftime('%Y-%m-%dT%H:%M:%SZ', 'now')
      );
    end;
    """

    execute """
    create trigger tracks_delete
    after delete on tracks
    begin
      insert into deletion_log (entity_type, entity_id, metadata, deleted_at)
      values (
        'track',
        OLD.id,
        json_object('name', OLD.name),
        strftime('%Y-%m-%dT%H:%M:%SZ', 'now')
      );
    end;
    """

    execute """
    create trigger albums_delete
    after delete on albums
    begin
      insert into deletion_log (entity_type, entity_id, metadata, deleted_at)
      values (
        'album',
        OLD.id,
        json_object('name', OLD.name),
        strftime('%Y-%m-%dT%H:%M:%SZ', 'now')
      );
    end;
    """

    execute """
    create trigger artists_delete
    after delete on artists
    begin
      insert into deletion_log (entity_type, entity_id, metadata, deleted_at)
      values (
        'artist',
        OLD.id,
        json_object('name', OLD.name),
        strftime('%Y-%m-%dT%H:%M:%SZ', 'now')
      );
    end;
    """
  end

  def down do
    execute "drop trigger if exists files_delete"
    execute "drop trigger if exists tracks_delete"
    execute "drop trigger if exists albums_delete"
    execute "drop trigger if exists artists_delete"
    drop table(:deletion_log)
  end
end
