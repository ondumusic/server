defmodule Ondu.Repo.Migrations.AddLoudness do
  use Ecto.Migration

  def change do
    alter table(:files) do
      add :loudness, :map
    end
  end
end
