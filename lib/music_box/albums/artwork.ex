defmodule MusicBox.Albums.Artwork do
  @moduledoc false

  use MusicBox.Schema

  alias MusicBox.Albums.Album
  alias MusicBox.Albums.CoverFile

  @type t :: %__MODULE__{}

  @type fetcher :: :cover_file | :embedded
  @fetchers ~w(cover_file embedded)a

  @primary_key {:album_id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id
  schema "album_artworks" do
    belongs_to :album, Album, define_field: false

    field :path, :string
    field :hash, :string
    field :width, :integer
    field :height, :integer
    field :fetcher, Ecto.Enum, values: @fetchers
    field :last_fetch_attempt, :utc_datetime

    # The file the artwork was found in (a cover file or a track).
    field :source_path, :string

    # The album directories (usually one, more for e.g. CD1/CD2) which are used
    # to detect cover files when scanning
    field :dirs, {:array, :string}

    # When present this contains information about the external cover file
    # to compare when it was added, changed or deleted.
    embeds_one :cover, CoverFile, on_replace: :update

    # Set by the scanner when a file inside the album changed and we should
    # refetch so see if the artwork has been updated/replaced.
    field :invalidated_at, :utc_datetime
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = struct, attrs) do
    struct
    |> cast(attrs, [
      :path,
      :hash,
      :width,
      :height,
      :fetcher,
      :last_fetch_attempt,
      :source_path,
      :dirs
    ])
    |> maybe_put_cover(attrs)
  end

  defp maybe_put_cover(changeset, %{cover: cover}), do: put_embed(changeset, :cover, cover)
  defp maybe_put_cover(changeset, _attrs), do: changeset

  @spec fetchers() :: [fetcher()]
  def fetchers, do: @fetchers
end
