defmodule MusicBox.ArtworkTest do
  use MusicBox.DataCase, async: false

  alias MusicBox.Albums.Album
  alias MusicBox.Artwork
  alias MusicBox.Artwork.Fetcher

  setup :set_mox_global

  setup_all do
    source_path = Path.absname("./tmp/test/artwork_source.jpg")
    File.mkdir_p!(Path.dirname(source_path))

    {_, 0} =
      System.cmd(
        "ffmpeg",
        ~w(-y -f lavfi -i color=c=red:s=800x800 -frames:v 1) ++ [source_path],
        stderr_to_stdout: true
      )

    [artwork_bytes: File.read!(source_path)]
  end

  setup %{artwork_bytes: artwork_bytes} do
    File.rm_rf!(MusicBox.Config.artwork_path())
    stub(MusicBox.Tool.ExtractArtworkMock, :exec, fn _path -> artwork_bytes end)
    :ok
  end

  describe "find/1" do
    test "saves resized artwork" do
      album = Repo.one!(Album)

      assert {:ok, artwork} = Artwork.find(album)
      assert artwork.fetcher == :embedded
      assert artwork.path == Fetcher.artwork_path(album)
      assert File.exists?(artwork.path)
      assert [artwork_file] = File.ls!(MusicBox.Config.artwork_path())
      assert artwork_file == "#{album.id}.jpg"
    end

    @tag capture_log: true
    test "does not store path when resizing fails" do
      stub(MusicBox.Tool.ExtractArtworkMock, :exec, fn _path -> :crypto.strong_rand_bytes(128) end)

      album = Repo.one!(Album)

      assert {:ok, artwork} = Artwork.find(album)
      assert artwork.path == nil
      assert File.ls!(MusicBox.Config.artwork_path()) == []
    end
  end

  describe "worker" do
    setup do
      Phoenix.PubSub.subscribe(MusicBox.PubSub, "library:sync")
      insert_albums(6)
      :ok
    end

    test "never fetches the same album concurrently", %{artwork_bytes: artwork_bytes} do
      pid = self()
      in_progress = :ets.new(:in_progress, [:public])

      stub(MusicBox.Tool.ExtractArtworkMock, :exec, fn path ->
        if :ets.update_counter(in_progress, path, 1, {path, 0}) > 1,
          do: send(pid, {:concurrent_fetch, path})

        Process.sleep(50)
        :ets.update_counter(in_progress, path, -1)
        artwork_bytes
      end)

      start_supervised!(Artwork.Worker)

      album_ids = Repo.all(from(al in Album, select: al.id))

      for album_id <- album_ids do
        assert_receive %{event: "processed", payload: %{albums: [^album_id]}}
      end

      refute_received {:concurrent_fetch, _path}

      for album <- Repo.all(from(al in Album, preload: :artwork)) do
        assert File.exists?(album.artwork.path)
      end
    end

    @tag capture_log: true
    test "keeps processing when a fetch crashes", %{artwork_bytes: artwork_bytes} do
      stub(MusicBox.Tool.ExtractArtworkMock, :exec, fn path ->
        if path =~ "Track 1.", do: raise("boom"), else: artwork_bytes
      end)

      worker_pid = start_supervised!(Artwork.Worker)

      album_ids =
        Repo.all(from(al in Album, where: al.name != "Album 1", select: al.id))

      for album_id <- album_ids do
        assert_receive %{event: "processed", payload: %{albums: [^album_id]}}
      end

      assert eventually(fn -> :sys.get_state(worker_pid) == %{} end)
    end
  end

  defp insert_albums(count) do
    TestSeeds.insert_artist(%{
      name: "Artwork Artist",
      albums:
        for i <- 1..count do
          %{
            name: "Album #{i}",
            release_year: 2000,
            tracks: [%{track: 1, name: "Track #{i}."}]
          }
        end
    })
  end

  defp eventually(fun, attempts \\ 30) do
    if fun.() or attempts == 0 do
      fun.()
    else
      Process.sleep(50)
      eventually(fun, attempts - 1)
    end
  end
end
