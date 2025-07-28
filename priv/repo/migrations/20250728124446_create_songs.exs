defmodule MusicBox.Repo.Migrations.CreateSongs do
  use Ecto.Migration

  def change do
    create table(:songs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :artist_id, :uuid
      add :album_id, :uuid
      add :name, :string
      add :duration, :float

      timestamps(type: :utc_datetime)
    end
  end
end
