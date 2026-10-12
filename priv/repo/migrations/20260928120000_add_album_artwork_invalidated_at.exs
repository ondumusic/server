defmodule Ondu.Repo.Migrations.AddAlbumArtworkInvalidatedAt do
  use Ecto.Migration

  def change do
    alter table(:album_artworks) do
      add :invalidated_at, :utc_datetime, null: true
    end
  end
end
