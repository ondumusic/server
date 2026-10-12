defmodule Ondu.Repo.Migrations.CreateArtistArtworks do
  use Ecto.Migration

  def change do
    create table(:artist_artworks, primary_key: false) do
      add :artist_id, references(:artists, type: :binary_id, on_delete: :delete_all),
        primary_key: true

      add :hash, :string, null: false
      add :width, :integer, null: false
      add :height, :integer, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
