defmodule Ondu.Repo.Migrations.AddSettings do
  use Ecto.Migration

  def change do
    create table(:settings, primary_key: false) do
      add :is_current, :boolean, null: false, default: true
      add :music_path, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:settings, [:is_current], where: "is_current")
  end
end
