defmodule MusicBox.Repo.Migrations.AddFilesContentChangedAt do
  use Ecto.Migration

  def up do
    alter table(:files) do
      add :content_changed_at, :utc_datetime, null: true
    end

    flush()

    execute "UPDATE files SET content_changed_at = inserted_at"
  end

  def down do
    alter table(:files) do
      remove :content_changed_at
    end
  end
end
