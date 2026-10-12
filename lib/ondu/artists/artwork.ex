defmodule Ondu.Artists.Artwork do
  @moduledoc false

  use Ondu.Schema

  alias Ondu.Artists.Artist

  @type t :: %__MODULE__{}

  @primary_key {:artist_id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id
  schema "artist_artworks" do
    belongs_to :artist, Artist, define_field: false

    # A hash of the uploaded image, and its dimensions.
    field :hash, :string
    field :width, :integer
    field :height, :integer

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = struct, attrs) do
    struct
    |> cast(attrs, [:hash, :width, :height])
    |> validate_required([:hash, :width, :height])
  end
end
