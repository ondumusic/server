defmodule Ondu.Repo.Migrations.AddSyncCursorIndexes do
  use Ecto.Migration

  def change do
    create index(:artists, [:updated_at, :id], comment: "sync cursor")
    create index(:albums, [:updated_at, :id], comment: "sync cursor")
    create index(:tracks, [:updated_at, :id], comment: "sync cursor")
    create index(:deletion_log, [:deleted_at, :entity_id], comment: "sync cursor")
  end
end
