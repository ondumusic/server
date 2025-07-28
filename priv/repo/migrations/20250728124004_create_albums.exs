defmodule MusicBox.Repo.Migrations.CreateAlbums do
  use Ecto.Migration

  def change do
    create table(:albums, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :artist_id, references(:artists, type: :binary_id, on_delete: :delete_all)
      add :name, :string, collate: :nocase
      add :release_year, :integer, null: true

      timestamps(type: :utc_datetime)
    end
  end
end
