defmodule Ondu.Repo.Migrations.AddSortNamePrefixSetting do
  use Ecto.Migration

  def change do
    alter table(:settings) do
      add :strip_sort_prefixes, {:array, :string}, default: []
    end
  end
end
