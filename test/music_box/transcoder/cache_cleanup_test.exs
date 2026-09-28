defmodule MusicBox.Transcoder.CacheCleanupTest do
  use MusicBox.DataCase, async: false

  alias MusicBox.Files.File, as: MediaFile
  alias MusicBox.Transcoder.CacheCleanup

  @now ~U[2026-06-01 12:00:00Z]
  @old ~U[2026-06-01 10:00:00Z]
  @recent ~U[2026-06-01 11:30:00Z]

  setup do
    cache_path = MusicBox.Config.transcode_cache_path()
    File.rm_rf!(cache_path)
    File.mkdir_p!(cache_path)

    files =
      from(f in MediaFile, order_by: f.path, limit: 3)
      |> Repo.all()
      |> Enum.map(&update_record(&1, %{content_changed_at: ~U[2026-01-01 00:00:00Z]}))

    [cache_path: cache_path, files: files]
  end

  test "removes transcodes of deleted files, changed files and unknown presets", %{
    cache_path: cache_path,
    files: [kept, changed | _]
  } do
    update_record(changed, %{content_changed_at: ~U[2026-06-01 11:00:00Z]})

    write_transcode(kept.id, "default_opus", 10, @old)
    write_transcode(kept.id, "removed_preset", 10, @old)
    write_transcode(changed.id, "default_opus", 10, @old)
    write_transcode(Ecto.UUID.generate(), "default_opus", 10, @old)
    File.write!(Path.join(cache_path, "notes.txt"), "not a transcode")

    assert {:ok, 3} = CacheCleanup.run(now: @now, max_size: nil)

    assert Enum.sort(File.ls!(cache_path)) ==
             Enum.sort(["#{kept.id}-default_opus.opus", "notes.txt"])
  end

  test "keeps transcodes completed in the last hour", %{cache_path: cache_path} do
    deleted_file_id = Ecto.UUID.generate()
    write_transcode(deleted_file_id, "default_opus", 10, @recent)

    assert {:ok, 0} = CacheCleanup.run(now: @now, max_size: 1)
    assert File.ls!(cache_path) == ["#{deleted_file_id}-default_opus.opus"]
  end

  test "removes the oldest transcodes over the maximum size", %{
    cache_path: cache_path,
    files: [first, second, third]
  } do
    write_transcode(first.id, "default_opus", 10, ~U[2026-06-01 08:00:00Z])
    write_transcode(second.id, "default_opus", 10, ~U[2026-06-01 09:00:00Z])
    write_transcode(third.id, "default_opus", 10, @old)
    # Counts towards the size, but is too recent to remove.
    write_transcode(first.id, "mobile_opus", 10, @recent)

    assert {:ok, 2} = CacheCleanup.run(now: @now, max_size: 25)

    assert Enum.sort(File.ls!(cache_path)) ==
             Enum.sort(["#{third.id}-default_opus.opus", "#{first.id}-mobile_opus.opus"])
  end

  test "does not limit the size without a maximum size", %{
    cache_path: cache_path,
    files: [first, second | _]
  } do
    write_transcode(first.id, "default_opus", 10, @old)
    write_transcode(second.id, "default_opus", 10, @old)

    assert {:ok, 0} = CacheCleanup.run(now: @now, max_size: nil)
    assert length(File.ls!(cache_path)) == 2
  end

  defp write_transcode(file_id, preset_id, size, completed_at) do
    path = Path.join(MusicBox.Config.transcode_cache_path(), "#{file_id}-#{preset_id}.opus")
    File.write!(path, :binary.copy("x", size))
    File.touch!(path, DateTime.to_unix(completed_at))
  end
end
