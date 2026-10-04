defmodule MusicBox.Repo.Migrations.AddFilesSizeIndex do
  use Ecto.Migration

  def change do
    create index(:files, [:size])
  end
end
