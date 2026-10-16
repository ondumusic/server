defmodule Ondu.Repo.Migrations.AddTracksDurationIndex do
  use Ecto.Migration

  def change do
    # This index is used to find possible replacement candidate tracks,
    # which are tracks whose files have changed (for example new tags).
    create index(:tracks, [:duration])
  end
end
