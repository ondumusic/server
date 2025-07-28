defmodule MusicBox.AlbumsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MusicBox.Albums` context.
  """

  @doc """
  Generate a album.
  """
  def album_fixture(attrs \\ %{}) do
    {:ok, album} =
      attrs
      |> Enum.into(%{
        artist_id: "7488a646-e31f-11e4-aace-600308960662",
        name: "some name",
        release_year: 42
      })
      |> MusicBox.Albums.create_album()

    album
  end
end
