defmodule MusicBox.FilesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MusicBox.Files` context.
  """

  @doc """
  Generate a file.
  """
  def file_fixture(attrs \\ %{}) do
    {:ok, file} =
      attrs
      |> Enum.into(%{
        last_scanned_at: ~U[2025-07-27 11:55:00Z],
        path: "some path"
      })
      |> MusicBox.Files.create_file()

    file
  end
end
