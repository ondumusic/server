defmodule MusicBox.Artists do
  @moduledoc """
  The Artists context.
  """

  import Ecto.Query, warn: false
  alias MusicBox.Repo

  alias MusicBox.Artists.Artist

  @doc """
  Returns the list of artists.

  ## Examples

      iex> list_artists()
      [%Artist{}, ...]

  """
  def list_artists do
    from(a in Artist,
      left_join: al in assoc(a, :albums),
      order_by: [asc: a.name],
      group_by: a.id,
      select: %{a | album_count: count(al.id)}
    )
    |> Repo.all()
  end

  def paginate_artists(params) do
    from(a in Artist,
      left_join: al in assoc(a, :albums),
      order_by: [asc: a.name],
      group_by: a.id,
      select: %{a | album_count: count(al.id)}
    )
    |> Repo.paginate(params, default_limit: 100)
  end

  @doc """
  Gets a single artist.

  Raises `Ecto.NoResultsError` if the Artist does not exist.

  ## Examples

      iex> get_artist!(123)
      %Artist{}

      iex> get_artist!(456)
      ** (Ecto.NoResultsError)

  """
  def get_artist!(id) do
    from(a in Artist,
      left_join: al in assoc(a, :albums),
      order_by: [asc: a.name],
      where: a.id == ^id,
      group_by: a.id,
      select: %{a | album_count: count(al.id)}
    )
    |> Repo.one!()
  end

  @doc """
  Creates a artist.

  ## Examples

      iex> create_artist(%{field: value})
      {:ok, %Artist{}}

      iex> create_artist(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_artist(attrs \\ %{}) do
    %Artist{}
    |> Artist.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a artist.

  ## Examples

      iex> update_artist(artist, %{field: new_value})
      {:ok, %Artist{}}

      iex> update_artist(artist, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_artist(%Artist{} = artist, attrs) do
    artist
    |> Artist.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a artist.

  ## Examples

      iex> delete_artist(artist)
      {:ok, %Artist{}}

      iex> delete_artist(artist)
      {:error, %Ecto.Changeset{}}

  """
  def delete_artist(%Artist{} = artist) do
    Repo.delete(artist)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking artist changes.

  ## Examples

      iex> change_artist(artist)
      %Ecto.Changeset{data: %Artist{}}

  """
  def change_artist(%Artist{} = artist, attrs \\ %{}) do
    Artist.changeset(artist, attrs)
  end
end
