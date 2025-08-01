defmodule MusicBox.Repo.Migrations.AddFileType do
  use Ecto.Migration

  def change do
    alter table(:files) do
      add :type, :string
    end
  end
end
