defmodule MusicBox.Repo.Migrations.AddDiscNumbers do
  use Ecto.Migration

  def change do
    alter table(:songs) do
      add :disc, :integer, default: 1, null: false
    end
  end
end
