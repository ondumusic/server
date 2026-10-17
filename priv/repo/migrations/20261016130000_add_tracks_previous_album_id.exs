defmodule Ondu.Repo.Migrations.AddTracksPreviousAlbumId do
  use Ecto.Migration

  def change do
    # Add a field to temporarily record the previously known album_id, so that
    # during file scans we can handle album rename scenarios.
    alter table(:tracks) do
      add :previous_album_id, references(:albums, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:tracks, [:previous_album_id])
  end
end
