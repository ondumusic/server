defmodule Ondu.FileScanner.MusicPathTest do
  use Ondu.DataCase, async: false

  alias Ondu.Files.File, as: MediaFile
  alias Ondu.FileScanner
  alias Ondu.FileScanner.Deletions
  alias Ondu.Settings

  setup do
    music_path = Path.absname("./tmp/test/music_path")
    File.rm_rf!(music_path)
    File.mkdir_p!(music_path)
    Settings.set(%{music_path: music_path})
    start_supervised!(FileScanner.Supervisor)

    # Scanned files have paths relative to the music path, seeds absolute ones.
    files =
      for file <- Repo.all(from(f in MediaFile, order_by: f.path)),
          do: update_record(file, %{path: String.trim_leading(file.path, "/")})

    [music_path: music_path, files: files]
  end

  defp restore(music_path, files) do
    for file <- files do
      path = Path.join(music_path, file.path)
      File.mkdir_p!(Path.dirname(path))
      File.touch!(path)
    end
  end

  describe "scan/1" do
    @tag capture_log: true
    test "does not scan when there is no music in the music path", %{music_path: music_path} do
      # Like an unmounted share with some system files.
      File.touch!(Path.join(music_path, ".DS_Store"))

      assert {:error, :music_path_unavailable} = FileScanner.scan(:full)
      assert Repo.aggregate(MediaFile, :count) == 14
    end

    @tag capture_log: true
    test "raises a notice while there is no music", %{music_path: music_path, files: files} do
      assert {:error, :music_path_unavailable} = FileScanner.scan(:full)
      assert [%{code: :library_unavailable}] = Ondu.Notices.active()

      restore(music_path, files)
      assert {:ok, :scan_completed} = FileScanner.scan(:quick)
      assert Ondu.Notices.active() == []
    end

    test "scans an empty music path for an empty library" do
      Repo.delete_all(MediaFile)

      assert {:ok, :scan_completed} = FileScanner.scan(:full)
    end
  end

  describe "find_missing_files/1" do
    test "deletes all missing files, also over several pages", %{
      music_path: music_path,
      files: files
    } do
      {missing, existing} = Enum.split(files, 4)
      restore(music_path, existing)

      missing_ids = Deletions.find_missing_files(batch_size: 2)
      assert Enum.sort(missing_ids) == Enum.sort(Enum.map(missing, & &1.id))
      assert {:ok, 4} = Deletions.delete_files(missing_ids)

      assert Enum.sort(Repo.all(from(f in MediaFile, select: f.id))) ==
               Enum.sort(Enum.map(existing, & &1.id))

      refute Enum.any?(missing, &Repo.get(MediaFile, &1.id))
    end
  end
end
