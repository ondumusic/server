defmodule Ondu.Repo.Migrations.AddSongTrackNo do
  use Ecto.Migration

  def change do
    alter table(:songs) do
      add :track, :integer, null: true, default: nil
    end
  end
end
