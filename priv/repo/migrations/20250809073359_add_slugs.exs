defmodule Ondu.Repo.Migrations.AddSlugs do
  use Ecto.Migration

  def change do
    alter table(:album_artists) do
      add :slug, :string
    end

    create unique_index(:album_artists, [:slug])
  end
end
