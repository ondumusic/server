defmodule Ondu.Repo.Migrations.RemoveTracksAlbumIdIndex do
  use Ecto.Migration

  # Lookups by album_id use tracks_album_id_disc_number_index, which starts with
  # the same column.
  def change do
    drop index(:tracks, [:album_id])
  end
end
