defmodule MusicBox.Repo.Migrations.AddAlbumArtworkSources do
  use Ecto.Migration

  def up do
    alter table(:album_artworks) do
      add :source_path, :string, null: true
      add :dirs, {:array, :string}, null: true
      add :cover, :map, null: true
    end

    flush()

    # Existing artwork was found before cover files were supported, looking it
    # up again fills in the new fields (and finds cover files next to tracks).
    execute """
    UPDATE album_artworks SET invalidated_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now')
    """
  end

  def down do
    alter table(:album_artworks) do
      remove :source_path
      remove :dirs
      remove :cover
    end
  end
end
