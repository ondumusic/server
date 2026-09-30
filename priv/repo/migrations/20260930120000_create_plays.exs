defmodule MusicBox.Repo.Migrations.CreatePlays do
  use Ecto.Migration

  def change do
    # Clients will be responsible for the id to allow idempotent submissions
    create table(:play_history, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :track_id, references(:tracks, type: :binary_id, on_delete: :delete_all), null: false
      add :played_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:play_history, [:track_id, :played_at])

    alter table(:tracks) do
      add :play_count, :integer, null: false, default: 0
      add :last_played_at, :utc_datetime
    end
  end
end
