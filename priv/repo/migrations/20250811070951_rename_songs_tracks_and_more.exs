defmodule Ondu.Repo.Migrations.RenameSongsTracksAndMore do
  use Ecto.Migration

  def change do
    # First clean up all outdated indexes, references and schemas
    drop unique_index(:albums, [:album_artist_id, :name])

    alter table(:albums) do
      remove :album_artist_id
    end

    alter table(:songs) do
      remove :artist_id
    end

    drop table(:album_artists)
    drop table(:artists)

    # Songs are now Tracks
    rename table(:songs), :track, to: :number
    rename table(:songs), to: table(:tracks)

    # We'll have a single Artists schema again
    create table(:artists, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, collate: :nocase
      add :slug, :string

      timestamps(type: :utc_datetime)
    end

    # Use the new mixed artists schema for albums and tracks
    alter table(:albums) do
      add :artist_id, references(:artists, type: :binary_id, on_delete: :delete_all), null: false
      add :slug, :string
    end

    alter table(:tracks) do
      add :artist_id, references(:artists, type: :binary_id, on_delete: :delete_all), null: true
    end

    create unique_index(:albums, [:artist_id, :slug])
    create unique_index(:artists, [:slug])
  end
end
