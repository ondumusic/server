defmodule MusicBox.Repo.Migrations.RemoveSearchTriggers do
  use Ecto.Migration

  def change do
    execute("drop trigger if exists tracks_after_insert;", "")
    execute("drop trigger if exists files_after_update;", "")
    execute("drop trigger if exists files_after_delete;", "")
  end
end
