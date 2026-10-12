defmodule Ondu.Repo.Migrations.AddTracksAlbumIdDiscNumberIndex do
  use Ecto.Migration

  def change do
    create index(:tracks, [:album_id, :disc, :number])
  end
end
