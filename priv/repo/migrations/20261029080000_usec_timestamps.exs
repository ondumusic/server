defmodule Ondu.Repo.Migrations.UsecTimestamps do
  use Ecto.Migration

  @columns [
    {"albums", ~w(inserted_at updated_at)},
    {"annotations", ~w(inserted_at updated_at)},
    {"artist_artworks", ~w(inserted_at updated_at)},
    {"artists", ~w(inserted_at updated_at)},
    {"deletion_log", ~w(deleted_at)},
    {"files", ~w(inserted_at updated_at)},
    {"play_history", ~w(inserted_at)},
    {"playlist_items", ~w(inserted_at updated_at)},
    {"playlists", ~w(inserted_at updated_at)},
    {"settings", ~w(inserted_at updated_at)},
    {"tracks", ~w(inserted_at updated_at)},
    {"user_sessions", ~w(inserted_at)},
    {"users", ~w(inserted_at updated_at)}
  ]

  @triggers [
    {"files", "file", "json_object('path', OLD.path)"},
    {"tracks", "track", "json_object('name', OLD.name)"},
    {"albums", "album", "json_object('name', OLD.name)"},
    {"artists", "artist", "json_object('name', OLD.name)"},
    {"playlists", "playlist", "null"},
    {"playlist_items", "playlist_item", "null"}
  ]

  def up do
    for {table, columns} <- @columns, column <- columns do
      execute """
      update #{table} set #{column} = replace(#{column}, 'Z', '.000000Z')
      where #{column} like '%Z' and #{column} not like '%.%'
      """
    end

    create_delete_triggers("strftime('%Y-%m-%dT%H:%M:%f', 'now') || '000Z'")
  end

  def down do
    create_delete_triggers("strftime('%Y-%m-%dT%H:%M:%SZ', 'now')")

    for {table, columns} <- @columns, column <- columns do
      execute """
      update #{table} set #{column} = substr(#{column}, 1, 19) || 'Z'
      where #{column} like '%.%'
      """
    end
  end

  defp create_delete_triggers(deleted_at) do
    for {table, entity_type, metadata} <- @triggers do
      execute "drop trigger if exists #{table}_delete"

      execute """
      create trigger #{table}_delete
      after delete on #{table}
      begin
        insert into deletion_log (entity_type, entity_id, metadata, deleted_at)
        values ('#{entity_type}', OLD.id, #{metadata}, #{deleted_at});
      end;
      """
    end
  end
end
