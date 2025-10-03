defmodule MusicBox.Repo.Migrations.AddTrackSlugs do
  use Ecto.Migration

  def change do
    alter table(:tracks) do
      add :slug, :string
    end
  end
end
