defmodule Ondu.CoverFilesTest do
  use Ondu.DataCase, async: false

  alias Ondu.Albums
  alias Ondu.Albums.{Album, CoverFile}
  alias Ondu.Artwork
  alias Ondu.Settings
  alias Ondu.Storage
  alias Ondu.Utils

  setup :set_mox_global

  setup_all do
    [
      embedded_bytes: image("red", "300x300"),
      cover_bytes: image("blue", "500x500")
    ]
  end

  setup %{embedded_bytes: embedded_bytes} = context do
    music_path = Path.absname("./tmp/test/cover_files/#{context.line}")
    File.rm_rf!(music_path)
    File.mkdir_p!(music_path)
    Settings.set(%{music_path: music_path})

    File.rm_rf!(Ondu.Config.artwork_path())
    stub(Ondu.Tool.ExtractArtworkMock, :exec, fn _path -> embedded_bytes end)

    [music_path: music_path]
  end

  describe "cover file names" do
    test "only matches known names and image extensions" do
      assert Utils.cover_file?("Artist/Album/cover.jpg")
      assert Utils.cover_file?("Artist/Album/Cover.JPG")
      assert Utils.cover_file?("folder.png")
      assert Utils.cover_file?("AlbumArt.webp")

      refute Utils.cover_file?("Artist/Album/back.jpg")
      refute Utils.cover_file?("Artist/Album/cover.gif")
      refute Utils.cover_file?("Artist/Album/cover.jpg.bak")
    end

    test "prefers cover files by name and then extension" do
      assert %CoverFile{path: "A/cover.png"} =
               CoverFile.find([entry("A/folder.jpg"), entry("A/cover.png")])

      assert %CoverFile{path: "A/cover.jpg"} =
               CoverFile.find([entry("A/cover.png"), entry("A/cover.jpg")])

      assert CoverFile.find([entry("A/01 Track.mp3")]) == nil
    end
  end

  describe "storage" do
    test "lists the files directly inside a directory", %{music_path: music_path} do
      write(music_path, "Album/cover.jpg", "cover")
      write(music_path, "Album/Disc 2/cover.jpg", "cover")

      assert [%{path: "Album/cover.jpg", size: 5, mtime: %DateTime{}}] =
               Storage.list_dir("Album")
    end

    test "walks cover files next to music files", %{music_path: music_path} do
      write(music_path, "Album/01.mp3", "music")
      write(music_path, "Album/cover.jpg", "cover")
      write(music_path, "Album/back.jpg", "not a cover")

      assert Storage.walk("/") |> Enum.map(& &1.path) == ["Album/01.mp3", "Album/cover.jpg"]
    end
  end

  describe "finding artwork" do
    test "prefers a cover file over embedded artwork", context do
      write(context.music_path, "Album/cover.jpg", context.cover_bytes)

      assert {:ok, artwork} = Albums.find_cover(insert_album("Album"))
      assert artwork.fetcher == :cover_file
      assert artwork.source_path == "Album/cover.jpg"
      assert {artwork.width, artwork.height} == {500, 500}
      assert artwork.dirs == ["Album"]
      assert %CoverFile{path: "Album/cover.jpg", size: size} = artwork.cover
      assert size == byte_size(context.cover_bytes)
    end

    test "uses embedded artwork without a cover file" do
      assert {:ok, artwork} = Albums.find_cover(insert_album("Album"))
      assert artwork.fetcher == :embedded
      assert artwork.source_path == "Album/One.mp3"
      assert {artwork.width, artwork.height} == {300, 300}
      assert artwork.dirs == ["Album"]
      assert artwork.cover == nil
    end

    test "finds a cover file in any of the album directories", context do
      write(context.music_path, "Multi/CD2/cover.jpg", context.cover_bytes)

      assert {:ok, artwork} = Albums.find_cover(insert_album(["Multi/CD1", "Multi/CD2"]))
      assert artwork.fetcher == :cover_file
      assert artwork.source_path == "Multi/CD2/cover.jpg"
      assert artwork.dirs == ["Multi/CD1", "Multi/CD2"]
    end

    test "prefers the first directory when they have the same cover file", context do
      write(context.music_path, "Multi/CD1/cover.jpg", context.cover_bytes)
      write(context.music_path, "Multi/CD2/cover.jpg", context.cover_bytes)

      assert {:ok, artwork} = Albums.find_cover(insert_album(["Multi/CD2", "Multi/CD1"]))
      assert artwork.source_path == "Multi/CD1/cover.jpg"
    end

    @tag capture_log: true
    test "falls back to embedded artwork when the cover file is broken", context do
      write(context.music_path, "Album/cover.jpg", :crypto.strong_rand_bytes(128))

      assert {:ok, artwork} = Albums.find_cover(insert_album("Album"))
      assert artwork.fetcher == :embedded

      # Still stored, so the scanner does not invalidate it again until it changes.
      assert %CoverFile{path: "Album/cover.jpg"} = artwork.cover
    end
  end

  describe "invalidate_cover_files/1" do
    setup do
      with_cover = insert_album("A")
      without_cover = insert_album("B")

      cover = %CoverFile{
        path: "A/cover.jpg",
        size: 10,
        last_modified_at: ~U[2026-01-01 00:00:00Z]
      }

      set_artwork(with_cover, "A", cover)
      set_artwork(without_cover, "B", nil)

      multi_disc = insert_album(["C/CD1", "C/CD2"])
      set_artwork(multi_disc, ["C/CD1", "C/CD2"], nil)

      [with_cover: with_cover, without_cover: without_cover, multi_disc: multi_disc]
    end

    test "keeps albums of which the cover files did not change", context do
      Albums.invalidate_cover_files([entry("A/cover.jpg", 10)])
      refute invalidated?(context.with_cover)
      refute invalidated?(context.without_cover)
    end

    test "invalidates albums of which a cover file was added", context do
      Albums.invalidate_cover_files([entry("A/cover.jpg", 10), entry("B/cover.jpg")])
      refute invalidated?(context.with_cover)
      assert invalidated?(context.without_cover)
    end

    test "invalidates albums of which a cover file was added in any directory", context do
      Albums.invalidate_cover_files([entry("A/cover.jpg", 10)])
      refute invalidated?(context.multi_disc)

      Albums.invalidate_cover_files([
        entry("A/cover.jpg", 10),
        entry("C/CD2/cover.jpg")
      ])

      assert invalidated?(context.multi_disc)
    end

    test "invalidates albums of which the cover file changed", context do
      Albums.invalidate_cover_files([entry("A/cover.jpg", 11)])
      assert invalidated?(context.with_cover)
    end

    test "invalidates albums of which the cover file was removed", context do
      Albums.invalidate_cover_files([])
      assert invalidated?(context.with_cover)
      refute invalidated?(context.without_cover)
    end

    test "invalidates albums when a better cover file was added", context do
      # folder.jpg is less preferred than the cover.jpg that is already used.
      Albums.invalidate_cover_files([entry("A/cover.jpg", 10), entry("A/folder.jpg")])
      refute invalidated?(context.with_cover)

      # cover.jpg was replaced by the less preferred cover.png.
      Albums.invalidate_cover_files([entry("A/cover.png", 10)])
      assert invalidated?(context.with_cover)
    end
  end

  describe "worker" do
    test "looks up invalidated artwork when a scan completed" do
      album = insert_album("Album")

      # All albums (including the seeded ones) have artwork, so there is
      # nothing to do when the worker starts.
      for album <- Repo.all(Album), do: {:ok, _artwork} = Albums.find_cover(album)
      start_supervised!(Artwork.Worker)

      from(aw in Albums.Artwork, where: aw.album_id == ^album.id)
      |> Repo.update_all(
        set: [
          last_fetch_attempt: ~U[2026-01-01 00:00:00Z],
          invalidated_at: ~U[2026-02-01 00:00:00Z]
        ]
      )

      OnduWeb.Endpoint.broadcast!("library:sync", "completed", %{})

      assert_eventually(fn ->
        DateTime.after?(
          Repo.get!(Albums.Artwork, album.id).last_fetch_attempt,
          ~U[2026-02-01 00:00:00Z]
        )
      end)
    end
  end

  defp image(color, size) do
    path = Path.absname("./tmp/test/cover_file_images/#{color}.jpg")
    File.mkdir_p!(Path.dirname(path))

    {_, 0} =
      System.cmd(
        "ffmpeg",
        ~w(-y -f lavfi -i color=c=#{color}:s=#{size} -frames:v 1 -update 1) ++ [path],
        stderr_to_stdout: true
      )

    File.read!(path)
  end

  defp write(music_path, path, contents) do
    path = Path.join(music_path, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
  end

  defp entry(path, size \\ 1), do: %{path: path, size: size, mtime: ~U[2026-01-01 00:00:00Z]}

  # An album with one track in each of the given directories.
  defp insert_album(dirs) do
    dirs = List.wrap(dirs)
    name = Enum.join(dirs, ", ")
    artist = TestSeeds.insert_artist(%{name: "Artist #{name}"})
    album = TestSeeds.insert_album(artist, %{name: "Album #{name}", release_year: 2000})

    for dir <- dirs do
      track = TestSeeds.insert_track(artist, album, %{name: "One #{dir}"})

      from(f in Ondu.Files.File, where: f.id == ^track.file_id)
      |> Repo.update_all(set: [path: "#{dir}/One.mp3"])
    end

    Repo.get!(Album, album.id)
  end

  defp set_artwork(album, dirs, cover) do
    {:ok, _artwork} =
      Albums.update_artwork(album, %{
        fetcher: :embedded,
        last_fetch_attempt: ~U[2026-01-01 00:00:00Z],
        dirs: List.wrap(dirs),
        cover: cover
      })
  end

  defp invalidated?(album) do
    not is_nil(Repo.get!(Albums.Artwork, album.id).invalidated_at)
  end
end
