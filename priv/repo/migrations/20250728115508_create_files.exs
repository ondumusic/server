defmodule MusicBox.Repo.Migrations.CreateFiles do
  use Ecto.Migration

  def change do
    create table(:files, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :path, :string
      add :last_scanned_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end
  end
end
