defmodule Ondu.LoudnessTest do
  use Ondu.DataCase, async: false

  alias Ondu.Files.File
  alias Ondu.Loudness

  setup :set_mox_global

  setup do
    stub(Ondu.Tool.LoudnessMock, :exec, fn _path -> {:ok, %{lufs: -9.5, peak: -0.4}} end)
    :ok
  end

  describe "measure/1" do
    test "stores the measurement" do
      file = Repo.one!(from(f in File, limit: 1))

      assert {:ok, %{lufs: -9.5, peak: -0.4, measured_at: %DateTime{}}} = Loudness.measure(file)
      assert %{lufs: -9.5, peak: -0.4} = Repo.reload!(file).loudness
    end

    @tag capture_log: true
    test "allows half of the duration plus a minute to measure" do
      pid = self()

      stub(Ondu.Tool.LoudnessMock, :exec, fn [path: _path, timeout: timeout] ->
        send(pid, {:timeout, timeout})
        {:ok, %{lufs: -9.5, peak: -0.4}}
      end)

      file = Repo.one!(from(f in File, limit: 1))

      file =
        update_record(file, %{metadata: %{Map.from_struct(file.metadata) | duration: 3600.0}})

      Loudness.measure(file)
      assert_received {:timeout, 1_860_000}
    end

    test "stores a failed measurement without values" do
      stub(Ondu.Tool.LoudnessMock, :exec, fn _path -> {:error, :measure_failed} end)
      file = Repo.one!(from(f in File, limit: 1))

      assert {:ok, %{lufs: nil, peak: nil, measured_at: %DateTime{}}} = Loudness.measure(file)
      assert %{lufs: nil, measured_at: %DateTime{}} = Repo.reload!(file).loudness
    end

    test "touches the album so clients pick up its loudness on their next sync" do
      cursor = sync_cursor_in_the_past()
      file = Repo.one!(from(f in File, limit: 1))
      track = Repo.get_by!(Ondu.Tracks.Track, file_id: file.id)

      assert {:ok, _loudness} = Loudness.measure(file)

      assert %{albums: %{entries: [%{id: album_id}]}} =
               Ondu.Sync.get_entities(cursor)

      assert album_id == track.album_id
    end

    test "touches the track so clients pick it up on their next sync" do
      cursor = sync_cursor_in_the_past()
      file = Repo.one!(from(f in File, limit: 1))
      track = Repo.get_by!(Ondu.Tracks.Track, file_id: file.id)

      assert {:ok, _loudness} = Loudness.measure(file)

      assert %{tracks: %{entries: [%{id: track_id}]}} =
               Ondu.Sync.get_entities(cursor)

      assert track_id == track.id
    end

    @tag capture_log: true
    test "does not touch the track when measuring failed" do
      stub(Ondu.Tool.LoudnessMock, :exec, fn _path -> {:error, :measure_failed} end)
      cursor = sync_cursor_in_the_past()
      file = Repo.one!(from(f in File, limit: 1))

      assert {:ok, _loudness} = Loudness.measure(file)
      assert %{tracks: %{entries: []}} = Ondu.Sync.get_entities(cursor)
    end

    test "does not touch the track when re-measuring gives the same values" do
      file = Repo.one!(from(f in File, limit: 1))
      {:ok, _loudness} = Loudness.measure(file)

      cursor = sync_cursor_in_the_past()

      assert {:ok, _loudness} = Loudness.measure(Repo.reload!(file))
      assert %{tracks: %{entries: []}} = Ondu.Sync.get_entities(cursor)
    end

    test "touches the track when re-measuring gives different values" do
      file = Repo.one!(from(f in File, limit: 1))
      {:ok, _loudness} = Loudness.measure(file)

      cursor = sync_cursor_in_the_past()
      stub(Ondu.Tool.LoudnessMock, :exec, fn _path -> {:ok, %{lufs: -12.0, peak: -1.0}} end)

      assert {:ok, _loudness} = Loudness.measure(Repo.reload!(file))
      assert %{tracks: %{entries: [_track]}} = Ondu.Sync.get_entities(cursor)
    end

    test "does not store the measurement when the file changed meanwhile" do
      file = Repo.one!(from(f in File, limit: 1))
      Repo.update_all(from(f in File, where: f.id == ^file.id), inc: [size: 1])

      assert {:error, :file_changed} = Loudness.measure(file)
      assert is_nil(Repo.reload!(file).loudness)
    end
  end

  # Moves all tracks and albums back in time and returns a sync cursor after all
  # of them, so anything touched from now on shows up in the next sync.
  defp sync_cursor_in_the_past do
    past = DateTime.add(DateTime.utc_now(:second), -1, :hour)
    Repo.update_all(Ondu.Tracks.Track, set: [updated_at: past])
    Repo.update_all(Ondu.Albums.Album, set: [updated_at: past])

    result = Ondu.Sync.get_entities(%{}, 10_000)
    refute result.tracks.has_more?

    {:ok, cursor} = result |> Ondu.Sync.encode_cursor() |> Ondu.Sync.decode_cursor()
    cursor
  end

  describe "album_loudness/1" do
    test "is the energy average of the tracks weighted by duration" do
      tracks = [track(100.0, -10.0, -1.0), track(100.0, -20.0, -3.0)]

      # 10 * log10((10^-1 + 10^-2) / 2)
      assert %{lufs: -12.6, peak: -1.0} = Loudness.album_loudness(tracks)

      # A longer quiet track pulls the album down more.
      assert %{lufs: lufs} =
               Loudness.album_loudness([track(100.0, -10.0, -1.0), track(300.0, -20.0, -3.0)])

      assert lufs < -12.6
    end

    test "ignores tracks without a peak (digital silence) for the peak" do
      tracks = [track(100.0, -10.0, nil), track(100.0, -10.0, -2.5)]
      assert %{lufs: -10.0, peak: -2.5} = Loudness.album_loudness(tracks)
    end

    test "is nil until all tracks are measured" do
      assert Loudness.album_loudness([]) == nil
      assert Loudness.album_loudness([track(100.0, -10.0, -1.0), track(100.0, nil, nil)]) == nil

      unmeasured = %Ondu.Tracks.Track{duration: 100.0, file: %File{loudness: nil}}
      assert Loudness.album_loudness([track(100.0, -10.0, -1.0), unmeasured]) == nil
    end

    defp track(duration, lufs, peak) do
      %Ondu.Tracks.Track{
        duration: duration,
        file: %File{loudness: %Ondu.Files.Loudness{lufs: lufs, peak: peak}}
      }
    end
  end

  describe "worker" do
    test "measures every file once and never concurrently" do
      pid = self()
      in_progress = :ets.new(:in_progress, [:public])

      stub(Ondu.Tool.LoudnessMock, :exec, fn [path: path, timeout: _timeout] ->
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
        uri = Ondu.Storage.get_uri(path)
        assert_received {:measured, ^uri}
        refute_received {:measured, ^uri}
      end
    end

    test "measures files again when their content changed and keeps the old loudness meanwhile" do
      old = %Ondu.Files.Loudness{
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
      crashing_uri = Ondu.Storage.get_uri(crashing.path)

      stub(Ondu.Tool.LoudnessMock, :exec, fn
        [path: ^crashing_uri, timeout: _timeout] -> raise "boom"
        _args -> {:ok, %{lufs: -9.5, peak: -0.4}}
      end)

      worker_pid = start_supervised!(Loudness.Worker)

      assert_eventually(
        fn ->
          Repo.all(from(f in File, where: is_nil(f.loudness), select: f.id)) == [crashing.id]
        end,
        500
      )

      assert_eventually(fn -> map_size(:sys.get_state(worker_pid).running) == 0 end)
      assert crashing.id in :sys.get_state(worker_pid).crashed
    end
  end
end
