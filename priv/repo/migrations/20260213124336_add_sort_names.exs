defmodule MusicBox.Repo.Migrations.AddSortNames do
  use Ecto.Migration

  def change do
    alter table(:albums) do
      add :sort_name, :string, collate: :nocase, null: true
    end

    alter table(:artists) do
      add :sort_name, :string, collate: :nocase, null: true
    end

    execute "update albums set sort_name = name", "select 1"
    execute "update artists set sort_name = name", "select 1"
  end
end
