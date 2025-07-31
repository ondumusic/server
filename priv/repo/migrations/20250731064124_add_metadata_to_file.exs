defmodule MusicBox.Repo.Migrations.AddMetadataToFile do
  use Ecto.Migration

  def change do
    alter table(:files) do
      add :checksum, :string, null: false
      add :last_modified_at, :utc_datetime, null: false
      add :metadata, :json, null: false, default: "{}"
    end

    create unique_index(:files, [:path])
  end
end
