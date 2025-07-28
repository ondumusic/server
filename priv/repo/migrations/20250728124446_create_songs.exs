defmodule MusicBox.Repo.Migrations.CreateSongs do
  use Ecto.Migration

  def change do
    create table(:songs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :artist_id, references(:artists, type: :binary_id, on_delete: :delete_all)
      add :album_id, references(:albums, type: :binary_id, on_delete: :delete_all)
      add :file_id, references(:files, type: :binary_id, on_delete: :delete_all)
      add :name, :string
      add :duration, :float

      timestamps(type: :utc_datetime)
    end
  end
end
