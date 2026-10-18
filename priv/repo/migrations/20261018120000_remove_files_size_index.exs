defmodule Ondu.Repo.Migrations.RemoveFilesSizeIndex do
  use Ecto.Migration

  def change do
    # This index was previousy used to find moved files, but with the new
    # planner setup this is no longer needed.
    drop index(:files, [:size])
  end
end
