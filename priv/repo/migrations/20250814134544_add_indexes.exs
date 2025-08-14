defmodule MusicBox.Repo.Migrations.AddIndexes do
  use Ecto.Migration

  def change do
    create index(:albums, [:artist_id])
    create index(:tracks, [:artist_id, :album_id], where: "album_id is null")
  end
end
