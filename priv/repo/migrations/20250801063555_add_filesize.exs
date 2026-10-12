defmodule Ondu.Repo.Migrations.AddFilesize do
  use Ecto.Migration

  def change do
    alter table(:files) do
      add :size, :integer, null: false, default: 0
    end
  end
end
