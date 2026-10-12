defmodule Ondu.Repo.Migrations.AddTrackCounts do
  use Ecto.Migration

  def change do
    alter table(:albums) do
      add :track_count, :integer, default: 0
    end
  end
end
