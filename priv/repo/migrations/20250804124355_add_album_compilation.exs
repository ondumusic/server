defmodule Ondu.Repo.Migrations.AddAlbumCompilation do
  use Ecto.Migration

  def change do
    alter table(:albums) do
      add :compilation, :boolean, default: false
    end
  end
end
