defmodule MusicBox.FilesTest do
  use MusicBox.DataCase

  alias MusicBox.Files

  @moduletag :skip
  describe "files" do
    alias MusicBox.Files.File

    import MusicBox.FilesFixtures

    @invalid_attrs %{path: nil, last_scanned_at: nil}

    test "list_files/0 returns all files" do
      file = file_fixture()
      assert Files.list_files() == [file]
    end

    test "get_file!/1 returns the file with given id" do
      file = file_fixture()
      assert Files.get_file!(file.id) == file
    end

    test "create_file/1 with valid data creates a file" do
      valid_attrs = %{path: "some path", last_scanned_at: ~U[2025-07-27 11:55:00Z]}

      assert {:ok, %File{} = file} = Files.create_file(valid_attrs)
      assert file.path == "some path"
      assert file.last_scanned_at == ~U[2025-07-27 11:55:00Z]
    end

    test "create_file/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Files.create_file(@invalid_attrs)
    end

    test "update_file/2 with valid data updates the file" do
      file = file_fixture()
      update_attrs = %{path: "some updated path", last_scanned_at: ~U[2025-07-28 11:55:00Z]}

      assert {:ok, %File{} = file} = Files.update_file(file, update_attrs)
      assert file.path == "some updated path"
      assert file.last_scanned_at == ~U[2025-07-28 11:55:00Z]
    end

    test "update_file/2 with invalid data returns error changeset" do
      file = file_fixture()
      assert {:error, %Ecto.Changeset{}} = Files.update_file(file, @invalid_attrs)
      assert file == Files.get_file!(file.id)
    end

    test "delete_file/1 deletes the file" do
      file = file_fixture()
      assert {:ok, %File{}} = Files.delete_file(file)
      assert_raise Ecto.NoResultsError, fn -> Files.get_file!(file.id) end
    end

    test "change_file/1 returns a file changeset" do
      file = file_fixture()
      assert %Ecto.Changeset{} = Files.change_file(file)
    end
  end
end
