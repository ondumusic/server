defmodule MusicBox.LoudnessTest do
  use MusicBox.DataCase, async: false

  alias MusicBox.Files.File
  alias MusicBox.Loudness

  setup :set_mox_global

  setup do
    stub(MusicBox.Tool.LoudnessMock, :exec, fn _path -> {:ok, %{lufs: -9.5, peak: -0.4}} end)
    :ok
  end

  describe "measure/1" do
    test "stores the measurement" do
      file = Repo.one!(from(f in File, limit: 1))

      assert {:ok, %{lufs: -9.5, peak: -0.4, measured_at: %DateTime{}}} = Loudness.measure(file)
      assert %{lufs: -9.5, peak: -0.4} = Repo.reload!(file).loudness
    end

    @tag capture_log: true
    test "stores a failed measurement without values" do
      stub(MusicBox.Tool.LoudnessMock, :exec, fn _path -> {:error, :measure_failed} end)
      file = Repo.one!(from(f in File, limit: 1))

      assert {:ok, %{lufs: nil, peak: nil, measured_at: %DateTime{}}} = Loudness.measure(file)
      assert %{lufs: nil, measured_at: %DateTime{}} = Repo.reload!(file).loudness
    end

    test "touches the track so clients pick it up on their next sync" do
      cursor = sync_cursor_in_the_past()
      file = Repo.one!(from(f in File, limit: 1))
      track = Repo.get_by!(MusicBox.Tracks.Track, file_id: file.id)

      assert {:ok, _loudness} = Loudness.measure(file)

      assert %{tracks: %{entries: [%{id: track_id}]}} =
               MusicBox.Sync.get_entities(%{"cursor" => cursor})

      assert track_id == track.id
    end

    @tag capture_log: true
    test "does not touch the track when measuring failed" do
      stub(MusicBox.Tool.LoudnessMock, :exec, fn _path -> {:error, :measure_failed} end)
      cursor = sync_cursor_in_the_past()
      file = Repo.one!(from(f in File, limit: 1))

      assert {:ok, _loudness} = Loudness.measure(file)
      assert %{tracks: %{entries: []}} = MusicBox.Sync.get_entities(%{"cursor" => cursor})
    end

    test "does not touch the track when re-measuring gives the same values" do
      file = Repo.one!(from(f in File, limit: 1))
      {:ok, _loudness} = Loudness.measure(file)

      cursor = sync_cursor_in_the_past()

      assert {:ok, _loudness} = Loudness.measure(Repo.reload!(file))
      assert %{tracks: %{entries: []}} = MusicBox.Sync.get_entities(%{"cursor" => cursor})
    end

    test "touches the track when re-measuring gives different values" do
      file = Repo.one!(from(f in File, limit: 1))
      {:ok, _loudness} = Loudness.measure(file)

      cursor = sync_cursor_in_the_past()
      stub(MusicBox.Tool.LoudnessMock, :exec, fn _path -> {:ok, %{lufs: -12.0, peak: -1.0}} end)

      assert {:ok, _loudness} = Loudness.measure(Repo.reload!(file))
      assert %{tracks: %{entries: [_track]}} = MusicBox.Sync.get_entities(%{"cursor" => cursor})
    end

    test "does not store the measurement when the file changed meanwhile" do
      file = Repo.one!(from(f in File, limit: 1))
      Repo.update_all(from(f in File, where: f.id == ^file.id), inc: [size: 1])

      assert {:error, :file_changed} = Loudness.measure(file)
      assert is_nil(Repo.reload!(file).loudness)
    end
  end

  # Moves all tracks back in time and returns a sync cursor after all of them,
  # so anything touched from now on shows up in the next sync.
  defp sync_cursor_in_the_past do
    past = DateTime.add(DateTime.utc_now(:second), -1, :hour)
    Repo.update_all(MusicBox.Tracks.Track, set: [updated_at: past])

    params = %{"limit" => 10_000}
    result = MusicBox.Sync.get_entities(params)
    refute result.tracks.has_more?

    MusicBox.Sync.encode_cursor(result, params)
  end

  describe "worker" do
    test "measures every file once and never concurrently" do
      pid = self()
      in_progress = :ets.new(:in_progress, [:public])

      stub(MusicBox.Tool.LoudnessMock, :exec, fn path ->
        if :ets.update_counter(in_progress, path, 1, {path, 0}) > 1,
          do: send(pid, {:concurrent_measure, path})

        send(pid, {:measured, path})
        Process.sleep(5)
        :ets.update_counter(in_progress, path, -1)
        {:ok, %{lufs: -9.5, peak: -0.4}}
      end)

      start_supervised!(Loudness.Worker)

      assert_eventually(
        fn ->
          Repo.aggregate(from(f in File, where: is_nil(f.loudness)), :count) == 0
        end,
        500
      )

      refute_received {:concurrent_measure, _path}

      paths = Repo.all(from(f in File, select: f.path))

      for path <- paths do
        uri = MusicBox.Storage.get_uri(path)
        assert_received {:measured, ^uri}
        refute_received {:measured, ^uri}
      end
    end

    test "measures files again when their content changed and keeps the old loudness meanwhile" do
      old = %MusicBox.Files.Loudness{
        lufs: -20.0,
        peak: -3.0,
        measured_at: ~U[2026-01-01 00:00:00Z]
      }

      Repo.update_all(File, set: [loudness: old, content_changed_at: ~U[2025-12-01 00:00:00Z]])

      [changed | _] = Repo.all(from(f in File, order_by: f.path))
      update_record(changed, %{content_changed_at: ~U[2026-02-01 00:00:00Z]})

      start_supervised!(Loudness.Worker)

      assert_eventually(fn -> Repo.reload!(changed).loudness.lufs == -9.5 end, 500)

      # Files that did not change after they were measured are not measured again.
      for file <- Repo.all(from(f in File, where: f.id != ^changed.id)) do
        assert file.loudness.lufs == -20.0
      end
    end

    @tag capture_log: true
    test "skips files that crash and keeps measuring the rest" do
      [crashing | _] = Repo.all(from(f in File, order_by: f.path))
      crashing_uri = MusicBox.Storage.get_uri(crashing.path)

      stub(MusicBox.Tool.LoudnessMock, :exec, fn
        ^crashing_uri -> raise "boom"
        _path -> {:ok, %{lufs: -9.5, peak: -0.4}}
      end)

      worker_pid = start_supervised!(Loudness.Worker)

      assert_eventually(
        fn ->
          Repo.all(from(f in File, where: is_nil(f.loudness), select: f.id)) == [crashing.id]
        end,
        500
      )

      assert_eventually(fn -> map_size(:sys.get_state(worker_pid).running) == 0 end)
      assert MapSet.member?(:sys.get_state(worker_pid).crashed, crashing.id)
    end
  end
end
