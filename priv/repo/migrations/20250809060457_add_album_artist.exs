defmodule Ondu.Repo.Migrations.AddAlbumArtist do
  use Ecto.Migration

  def change do
    create table(:album_artists, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, collate: :nocase

      timestamps(type: :utc_datetime)
    end

    create unique_index(:album_artists, [:name])

    drop unique_index(:albums, [:artist_id, :name])

    alter table(:albums) do
      remove :artist_id
      add :album_artist_id, references(:album_artists, type: :binary_id, on_delete: :delete_all)
    end

    create unique_index(:albums, [:album_artist_id, :name])
  end
end
