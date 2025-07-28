defmodule MusicBox.SongsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MusicBox.Songs` context.
  """

  @doc """
  Generate a song.
  """
  def song_fixture(attrs \\ %{}) do
    {:ok, song} =
      attrs
      |> Enum.into(%{
        album_id: "7488a646-e31f-11e4-aace-600308960662",
        artist_id: "7488a646-e31f-11e4-aace-600308960662",
        duration: 120.5,
        name: "some name"
      })
      |> MusicBox.Songs.create_song()

    song
  end
end
