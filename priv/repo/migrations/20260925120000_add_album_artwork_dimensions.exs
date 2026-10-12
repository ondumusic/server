defmodule Ondu.Repo.Migrations.AddAlbumArtworkDimensions do
  use Ecto.Migration

  def change do
    alter table(:album_artworks) do
      add :width, :integer, null: true
      add :height, :integer, null: true
    end
  end
end
