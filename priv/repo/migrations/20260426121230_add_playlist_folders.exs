defmodule MusicBox.Repo.Migrations.AddPlaylistFolders do
  use Ecto.Migration

  def change do
    alter table(:playlists) do
      add :is_folder, :boolean, default: false
      add :parent_id, references(:playlists, type: :binary_id, on_delete: :delete_all)
    end
  end
end
