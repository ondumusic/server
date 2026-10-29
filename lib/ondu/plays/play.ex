defmodule Ondu.Plays.Play do
  @moduledoc false

  use Ondu.Schema

  alias Ondu.Tracks.Track

  @type t :: %__MODULE__{}

  # Clients will be responsible for the id to allow idempotent submissions
  # so we should not autogenerate it on the server.
  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id
  schema "play_history" do
    field :played_at, :utc_datetime

    belongs_to :track, Track

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end
end
