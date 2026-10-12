defmodule Ondu.Storage.FileTest do
  use ExUnit.Case, async: true

  alias Ondu.Storage

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    contents = :crypto.strong_rand_bytes(200_000)
    path = Path.join(tmp_dir, "file.bin")
    File.write!(path, contents)
    [path: path, contents: contents]
  end

  test "streams a range of bytes in blocks", %{path: path, contents: contents} do
    blocks = path |> Storage.File.stream!(1_000..150_999) |> Enum.to_list()

    assert length(blocks) == 3
    assert IO.iodata_to_binary(blocks) == binary_part(contents, 1_000, 150_000)
  end

  test "stops at the end of the file", %{path: path, contents: contents} do
    data = path |> Storage.File.stream!(199_990..300_000) |> Enum.join()
    assert data == binary_part(contents, 199_990, 10)
  end

  describe "symlinks" do
    setup %{tmp_dir: tmp_dir} do
      music = Path.join(tmp_dir, "music")
      outside = Path.join(tmp_dir, "outside")

      for dir <- [music, Path.join(music, "album"), outside], do: File.mkdir_p!(dir)
      for file <- ["album/track.mp3", "album/cover.jpg"], do: File.touch!(Path.join(music, file))
      File.touch!(Path.join(outside, "other.mp3"))

      # A loop, a linked file inside and a linked folder outside the music path.
      File.ln_s!(music, Path.join(music, "album/loop"))
      File.ln_s!(Path.join(music, "album/track.mp3"), Path.join(music, "album/link.mp3"))
      File.ln_s!(Path.join(music, "album/cover.jpg"), Path.join(music, "album/front.jpg"))
      File.ln_s!(outside, Path.join(music, "outside"))

      [music: music]
    end

    test "does not follow symlinks", %{music: music} do
      expected = [Path.join(music, "album/cover.jpg"), Path.join(music, "album/track.mp3")]

      assert music |> Storage.File.walk() |> Enum.map(& &1.path) == expected

      assert music |> Path.join("album") |> Storage.File.list_dir() |> Enum.map(& &1.path) ==
               expected
    end

    test "finds files that are missing or became a symlink", %{music: music} do
      paths = Enum.map(["track.mp3", "link.mp3", "gone.mp3"], &Path.join([music, "album", &1]))

      assert paths |> Storage.File.find_missing_files() |> Enum.to_list() == tl(paths)
    end

    test "follows the music path when it is a symlink", %{music: music, tmp_dir: tmp_dir} do
      linked = Path.join(tmp_dir, "linked")
      File.ln_s!(music, linked)

      assert [_cover, _track] = linked |> Storage.File.walk() |> Enum.to_list()
    end
  end
end
