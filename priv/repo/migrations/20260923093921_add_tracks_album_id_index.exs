defmodule MusicBox.Repo.Migrations.AddTracksAlbumIdIndex do
  use Ecto.Migration

  def change do
    create index(:tracks, [:album_id])
  end
end
