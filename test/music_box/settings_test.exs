defmodule MusicBox.SettingsTest do
  use MusicBox.DataCase

  alias MusicBox.Settings

  describe "get/0" do
    test "creates new record if none found" do
      refute Repo.exists?(Settings)
      assert %Settings{is_current: true} = Settings.get()
      assert Repo.exists?(Settings)
    end

    test "returns settings" do
      music_path = Path.join(__DIR__, "../support/fixtures/")
      Settings.set(%{music_path: music_path})
      assert %Settings{is_current: true, music_path: ^music_path} = Settings.get()
    end
  end

  describe "set/1" do
    test "updated settings" do
      assert %Settings{music_path: nil} = Settings.get()
      music_path = Path.join(__DIR__, "../support/fixtures/")
      Settings.set(%{music_path: music_path})
      assert %Settings{music_path: ^music_path} = Settings.get()
    end

    test "fails if relative path" do
      assert %Settings{music_path: nil} = Settings.get()
      music_path = "../support/fixtures"
      assert {:error, changeset} = Settings.set(%{music_path: music_path})
      assert [music_path: {"should be an absolute path", []}] = changeset.errors
    end

    test "fails if invalid path" do
      assert %Settings{music_path: nil} = Settings.get()
      music_path = "/does/not/exist"
      assert {:error, changeset} = Settings.set(%{music_path: music_path})
      assert [music_path: {"is not a directory", []}] = changeset.errors
    end
  end
end
