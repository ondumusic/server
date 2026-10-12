defmodule Ondu.Repo.Migrations.CreatePlaylists do
  use Ecto.Migration

  def change do
    create table(:playlists, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :track_count, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create table(:playlist_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :playlist_id, references(:playlists, type: :binary_id, on_delete: :delete_all)
      add :track_id, references(:tracks, type: :binary_id, on_delete: :delete_all)
      add :position, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:playlists, [:updated_at, :id], comment: "sync cursor")

    create index(:playlist_items, [:playlist_id])
    create unique_index(:playlist_items, [:playlist_id, :position])
    create index(:playlist_items, [:updated_at, :id], comment: "sync cursor")
  end
end
