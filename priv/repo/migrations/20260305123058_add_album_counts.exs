defmodule Ondu.Repo.Migrations.AddAlbumCounts do
  use Ecto.Migration

  def change do
    alter table(:artists) do
      add :album_count, :integer, default: 0
    end
  end
end
