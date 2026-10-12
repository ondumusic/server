defmodule Ondu.Notices.Notice do
  @moduledoc false
  use Ondu.Schema

  @type t :: %__MODULE__{}

  @codes ~w(library_unavailable)a

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "notices" do
    field :code, Ecto.Enum, values: @codes
    field :level, Ecto.Enum, values: ~w(info warning)a

    # Clients show their own (translated) text for known codes, this English
    # message is used for codes they don't know.
    field :message, :string

    field :raised_at, :utc_datetime
    field :resolved_at, :utc_datetime
    field :dismissed_at, :utc_datetime
  end

  @spec codes() :: [atom()]
  def codes, do: @codes
end
