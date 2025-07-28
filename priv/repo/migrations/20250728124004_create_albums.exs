defmodule MusicBox.Repo.Migrations.CreateAlbums do
  use Ecto.Migration

  def change do
    create table(:albums, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :artist_id, :uuid
      add :name, :string
      add :release_year, :integer, null: true

      timestamps(type: :utc_datetime)
    end
  end
end
