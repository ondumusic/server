defmodule MusicBox.ArtworkTest do
  use MusicBox.DataCase, async: false

  alias MusicBox.Albums
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

    other_source_path = Path.absname("./tmp/test/artwork_other_source.jpg")

    {_, 0} =
      System.cmd(
        "ffmpeg",
        ~w(-y -f lavfi -i color=c=blue:s=600x600 -frames:v 1) ++ [other_source_path],
        stderr_to_stdout: true
      )

    [artwork_bytes: File.read!(source_path), other_artwork_bytes: File.read!(other_source_path)]
  end

  setup %{artwork_bytes: artwork_bytes} do
    File.rm_rf!(MusicBox.Config.artwork_path())
    stub(MusicBox.Tool.ExtractArtworkMock, :exec, fn _path -> artwork_bytes end)
    :ok
  end

  describe "find/1" do
    test "saves resized artwork variants" do
      album = Repo.one!(Album)

      assert {:ok, artwork} = Artwork.find(album)
      assert artwork.fetcher == :embedded
      assert artwork.path == Artwork.artwork_dir(album.id)
      assert {artwork.width, artwork.height} == {800, 800}
      assert File.ls!(MusicBox.Config.artwork_path()) == [album.id]
      assert Enum.sort(File.ls!(artwork.path)) == ["large.jpg", "thumbnail.jpg"]
      refute File.exists?(Fetcher.source_path(album))
    end

    test "touches the album so clients sync the new artwork urls" do
      album = Repo.one!(Album)
      update_record(album, %{updated_at: ~U[2000-01-01 00:00:00Z]})

      assert {:ok, _artwork} = Artwork.find(album)
      assert Repo.reload!(album).updated_at != ~U[2000-01-01 00:00:00Z]
    end

    test "re-import artwork stored without a hash (for old library migrations)" do
      album = Repo.one!(Album)

      {:ok, _artwork} =
        Albums.update_artwork(album, %{
          path: Artwork.artwork_dir(album.id),
          width: 800,
          height: 800,
          fetcher: :embedded,
          last_fetch_attempt: DateTime.utc_now()
        })

      assert {:ok, %{hash: hash}} = Artwork.find(album)
      assert is_binary(hash)
    end

    test "keeps the artwork when the source did not change" do
      album = Repo.one!(Album)
      assert {:ok, artwork} = Artwork.find(album)

      album = update_record(album, %{updated_at: ~U[2000-01-01 00:00:00Z]})
      # A resize would create this file again.
      File.rm!(Artwork.variant_path(album.id, :large))
      Phoenix.PubSub.subscribe(MusicBox.PubSub, "library:sync")

      assert {:ok, %{hash: hash}} = Artwork.find(album)
      assert hash == artwork.hash
      refute File.exists?(Artwork.variant_path(album.id, :large))
      assert Repo.reload!(album).updated_at == ~U[2000-01-01 00:00:00Z]
      refute_received %{event: "processed"}
    end

    test "replaces the artwork when the source changed", %{other_artwork_bytes: other_bytes} do
      album = Repo.one!(Album)
      assert {:ok, artwork} = Artwork.find(album)

      album = update_record(album, %{updated_at: ~U[2000-01-01 00:00:00Z]})
      stub(MusicBox.Tool.ExtractArtworkMock, :exec, fn _path -> other_bytes end)

      assert {:ok, new_artwork} = Artwork.find(album)
      assert new_artwork.hash != artwork.hash
      assert {new_artwork.width, new_artwork.height} == {600, 600}
      assert Repo.reload!(album).updated_at != ~U[2000-01-01 00:00:00Z]
    end

    test "clears the artwork when it is no longer found" do
      album = Repo.one!(Album)
      assert {:ok, _artwork} = Artwork.find(album)

      album = update_record(album, %{updated_at: ~U[2000-01-01 00:00:00Z]})
      stub(MusicBox.Tool.ExtractArtworkMock, :exec, fn _path -> {:error, :not_found} end)
      Phoenix.PubSub.subscribe(MusicBox.PubSub, "library:sync")

      assert {:ok, artwork} = Artwork.find(album)
      assert {artwork.path, artwork.hash, artwork.width} == {nil, nil, nil}
      refute File.exists?(Artwork.artwork_dir(album.id))
      assert Repo.reload!(album).updated_at != ~U[2000-01-01 00:00:00Z]

      album_id = album.id
      assert_received %{event: "processed", payload: %{albums: [^album_id]}}
    end

    test "does not reset the invalidation when storing a lookup" do
      album = Repo.one!(Album)
      assert {:ok, _artwork} = Artwork.find(album)

      from(aw in Albums.Artwork, where: aw.album_id == ^album.id)
      |> Repo.update_all(set: [invalidated_at: ~U[2030-01-01 00:00:00Z]])

      assert {:ok, _artwork} = Artwork.find(album)
      assert Repo.get!(Albums.Artwork, album.id).invalidated_at == ~U[2030-01-01 00:00:00Z]
    end

    @tag capture_log: true
    test "does not store path when resizing fails" do
      stub(MusicBox.Tool.ExtractArtworkMock, :exec, fn _path -> :crypto.strong_rand_bytes(128) end)

      album = Repo.one!(Album)

      assert {:ok, artwork} = Artwork.find(album)
      assert artwork.path == nil
      assert artwork.hash == nil
      assert artwork.width == nil
      assert Path.wildcard(Path.join(MusicBox.Config.artwork_path(), "**/*.*")) == []
    end
  end

  describe "variant_sizes/1" do
    test "fits the source within each variant without upscaling" do
      assert Artwork.variant_sizes(%Albums.Artwork{width: 1215, height: 1030}) ==
               [thumbnail: 128, large: 640]

      assert Artwork.variant_sizes(%Albums.Artwork{width: 450, height: 400}) ==
               [thumbnail: 128, large: 450]

      assert Artwork.variant_sizes(%Albums.Artwork{width: 90, height: 100}) ==
               [thumbnail: 100, large: 100]
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

    test "processes artwork that was stored without a hash" do
      # Every album has versioned artwork except "Album 1".
      for album <- Repo.all(Album) do
        Albums.update_artwork(album, %{
          path: Artwork.artwork_dir(album.id),
          hash: if(album.name == "Album 1", do: nil, else: "existing"),
          fetcher: :embedded,
          last_fetch_attempt: DateTime.utc_now()
        })
      end

      album_id = Repo.one!(from(al in Album, where: al.name == "Album 1", select: al.id))

      start_supervised!(Artwork.Worker)

      assert_receive %{event: "processed", payload: %{albums: [^album_id]}}
      refute_receive %{event: "processed"}, 200
      assert %{hash: hash} = Repo.get!(Albums.Artwork, album_id)
      assert hash not in [nil, "existing"]
    end

    test "looks up artwork again when it was invalidated after the last lookup" do
      for album <- Repo.all(Album) do
        Albums.update_artwork(album, %{
          path: Artwork.artwork_dir(album.id),
          hash: "existing",
          fetcher: :embedded,
          last_fetch_attempt: ~U[2026-01-01 00:00:00Z]
        })
      end

      # Invalidated before the last lookup, so already seen.
      Repo.update_all(Albums.Artwork, set: [invalidated_at: ~U[2025-12-01 00:00:00Z]])

      album_id = Repo.one!(from(al in Album, where: al.name == "Album 2", select: al.id))

      from(aw in Albums.Artwork, where: aw.album_id == ^album_id)
      |> Repo.update_all(set: [invalidated_at: ~U[2026-02-01 00:00:00Z]])

      start_supervised!(Artwork.Worker)

      assert_receive %{event: "processed", payload: %{albums: [^album_id]}}
      refute_receive %{event: "processed"}, 200

      assert %{hash: hash, last_fetch_attempt: last_fetch_attempt} =
               Repo.get!(Albums.Artwork, album_id)

      assert hash != "existing"
      assert DateTime.after?(last_fetch_attempt, ~U[2026-02-01 00:00:00Z])
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

      assert_eventually(fn -> :sys.get_state(worker_pid) == %{} end)
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
end
