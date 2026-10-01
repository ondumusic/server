defmodule MusicBox.ArtistArtworkTest do
  use MusicBox.DataCase, async: false

  alias MusicBox.Artists.{Artist, Artwork}
  alias MusicBox.Artwork, as: Artworks

  setup do
    File.rm_rf!(MusicBox.Config.artwork_path())
    dir = Path.absname("./tmp/test/artist_artwork")
    File.rm_rf!(dir)
    File.mkdir_p!(dir)

    artist = Artist |> first() |> Repo.one!()
    artist = update_record(artist, %{updated_at: ~U[2026-01-01 00:00:00Z]})

    [artist: artist, dir: dir]
  end

  defp image(dir, name, size) do
    path = Path.join(dir, name)

    # rgb24, older ffmpeg (6.x) rounds odd sizes down otherwise.
    {_, 0} =
      System.cmd(
        "ffmpeg",
        ~w(-y -f lavfi -i color=c=red:s=#{size},format=rgb24 -frames:v 1 -update 1 #{path}),
        stderr_to_stdout: true
      )

    path
  end

  test "stores the upload and variants that keep its aspect ratio", %{artist: artist, dir: dir} do
    path = image(dir, "photo.jpg", "1600x1000")

    assert {:ok, %Artwork{width: 1600, height: 1000}} = Artworks.put(:artists, artist, path)

    assert File.read!(Artworks.original_path(:artists, artist.id)) == File.read!(path)
    assert File.exists?(Artworks.variant_path(:artists, artist.id, :thumbnail))
    assert File.exists?(Artworks.variant_path(:artists, artist.id, :large))
    assert DateTime.after?(Repo.reload!(artist).updated_at, ~U[2026-01-01 00:00:00Z])

    assert Artworks.variant_sizes(:artists, %{width: 1600, height: 1000}) ==
             [{:thumbnail, 205, 128}, {:large, 1024, 640}]
  end

  test "replaces the artwork, but not with the same image", %{artist: artist, dir: dir} do
    {:ok, first} = Artworks.put(:artists, artist, image(dir, "first.png", "300x300"))
    artist = update_record(Repo.reload!(artist), %{updated_at: ~U[2026-01-01 00:00:00Z]})

    assert {:ok, %{hash: hash}} = Artworks.put(:artists, artist, Path.join(dir, "first.png"))
    assert hash == first.hash
    assert Repo.reload!(artist).updated_at == ~U[2026-01-01 00:00:00Z]

    assert {:ok, second} = Artworks.put(:artists, artist, image(dir, "second.png", "400x200"))
    assert second.hash != first.hash
    assert %{width: 400, height: 200} = Repo.get!(Artwork, artist.id)
  end

  @tag capture_log: true
  test "refuses files that are not images, or too large", %{artist: artist, dir: dir} do
    not_an_image = Path.join(dir, "notes.txt")
    File.write!(not_an_image, "not an image")

    too_large = Path.join(dir, "too_large.jpg")
    File.write!(too_large, :binary.copy(<<0>>, Artworks.max_size() + 1))

    assert {:error, :invalid_image} = Artworks.put(:artists, artist, not_an_image)
    assert {:error, :too_large} = Artworks.put(:artists, artist, too_large)

    assert {:error, :too_large} =
             Artworks.put(:artists, artist, image(dir, "huge.png", "10001x10"))

    refute Repo.get(Artwork, artist.id)
  end

  test "deletes the artwork", %{artist: artist, dir: dir} do
    {:ok, _artwork} = Artworks.put(:artists, artist, image(dir, "photo.png", "300x300"))

    assert :ok = Artworks.delete(:artists, artist)
    refute Repo.get(Artwork, artist.id)
    refute File.exists?(Artworks.dir(:artists, artist.id))
  end

  test "is removed together with the artist", %{artist: artist, dir: dir} do
    {:ok, _artwork} = Artworks.put(:artists, artist, image(dir, "photo.png", "300x300"))
    Repo.delete!(artist)

    refute Repo.get(Artwork, artist.id)
    assert Artworks.remove_orphaned() == 1
    refute File.exists?(Artworks.dir(:artists, artist.id))
  end
end
