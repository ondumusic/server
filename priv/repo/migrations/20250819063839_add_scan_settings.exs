defmodule Ondu.Repo.Migrations.AddScanSettings do
  use Ecto.Migration

  def change do
    alter table(:settings) do
      add :scan_type, :string, null: false, default: "quick"
      add :poll_interval, :integer, null: false, default: 60
    end
  end
end
