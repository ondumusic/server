defmodule Ondu.Repo.Migrations.CreateAnnotations do
  use Ecto.Migration

  def change do
    # One per entity in a namespace, the key is also used to list a namespace.
    create table(:annotations, primary_key: false) do
      add :namespace, :string, primary_key: true, null: false
      add :entity_type, :string, primary_key: true, null: false
      add :entity_id, :binary_id, primary_key: true, null: false
      add :data, :map, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
