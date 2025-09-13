defmodule MusicBox.Repo.Migrations.CreateArtwork do
  use Ecto.Migration

  def change do
    create table(:album_artworks, primary_key: false) do
      add :album_id, references(:albums, type: :binary_id, on_delete: :delete_all),
        primary_key: true

      add :path, :string, null: true
      add :fetcher, :string, null: false
      add :last_fetch_attempt, :utc_datetime, null: false
    end
  end
end
