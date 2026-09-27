defmodule MusicBox.Repo.Migrations.AddAlbumArtworkHash do
  use Ecto.Migration

  def change do
    alter table(:album_artworks) do
      add :hash, :string, null: true
    end
  end
end
