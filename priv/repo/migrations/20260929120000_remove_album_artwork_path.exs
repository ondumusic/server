defmodule MusicBox.Repo.Migrations.RemoveAlbumArtworkPath do
  use Ecto.Migration

  # The artwork location is derived from the album id and the artwork path, the
  # hash tells whether an album has artwork.
  def change do
    alter table(:album_artworks) do
      remove :path, :string, null: true
    end
  end
end
