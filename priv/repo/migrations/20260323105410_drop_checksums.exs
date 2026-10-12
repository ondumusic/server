defmodule Ondu.Repo.Migrations.DropChecksums do
  use Ecto.Migration

  def change do
    alter table(:files) do
      remove :checksum
    end
  end
end
