defmodule MusicBox.Repo.Migrations.CreateNotices do
  use Ecto.Migration

  def change do
    create table(:notices, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :code, :string, null: false
      add :level, :string, null: false
      add :message, :string, null: false
      add :raised_at, :utc_datetime, null: false
      add :resolved_at, :utc_datetime
      add :dismissed_at, :utc_datetime
    end

    # Only one notice per code can be active (not resolved) at a time.
    create unique_index(:notices, [:code], where: "resolved_at IS NULL")
  end
end
