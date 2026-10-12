defmodule Ondu.Tracks.IndexForm do
  @moduledoc false
  use Ondu.Schema

  @sort_options ~w(default random)a

  @primary_key false
  embedded_schema do
    field :sort_by, Ecto.Enum, values: @sort_options, default: :default
    field :artist_id, :binary_id
    field :album_id, :binary_id
    field :query, :string

    field :random_seed, :integer
  end

  @type t() :: %__MODULE__{}

  @spec new(t(), map()) :: t()
  def new(struct, params \\ %{}) do
    struct
    |> cast(params, __MODULE__.__schema__(:fields))
    |> maybe_set_default_seed()
    |> apply_changes()
  end

  defp maybe_set_default_seed(changeset) do
    if get_field(changeset, :sort_by) == :random and is_nil(get_field(changeset, :random_seed)) do
      put_change(changeset, :random_seed, :rand.uniform(1_000_000_000))
    else
      changeset
    end
  end
end
