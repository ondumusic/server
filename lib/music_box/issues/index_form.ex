defmodule MusicBox.Issues.IndexForm do
  @moduledoc false
  use MusicBox.Schema

  alias MusicBox.Issues.Rules

  @primary_key false
  embedded_schema do
    field :page, :integer, default: 1
    field :code, Ecto.Enum, values: Rules.codes()
  end

  @type t() :: %__MODULE__{}

  @spec new(t(), map()) :: t()
  def new(struct, params \\ %{}) do
    struct
    |> cast(params, __MODULE__.__schema__(:fields))
    |> update_change(:page, &max(&1, 1))
    |> apply_changes()
  end
end
