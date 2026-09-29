defmodule MusicBox.Storage.FileTest do
  use ExUnit.Case, async: true

  alias MusicBox.Storage

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
end
