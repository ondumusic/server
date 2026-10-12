defmodule Ondu.Repo.Migrations.AddUnknownAlbumFlag do
  use Ecto.Migration

  def change do
    alter table(:albums) do
      add :is_unknown, :boolean
    end
  end
end
