defmodule Ondu.Repo.Migrations.AddUniqueIndexes do
  use Ecto.Migration

  def change do
    create unique_index(:artists, [:name])
    create unique_index(:albums, [:artist_id, :name])
    create unique_index(:songs, [:file_id])
  end
end
