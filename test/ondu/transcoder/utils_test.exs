defmodule Ondu.Transcoder.UtilsTest do
  use ExUnit.Case, async: true

  alias Ondu.Transcoder.Utils

  describe "slice_chunk/4" do
    @chunk_size Utils.chunk_size()

    test "returns the part of a chunk within an inclusive range" do
      data = :binary.copy(<<1>>, @chunk_size)
      assert Utils.slice_chunk(data, 0, 10, 20) == :binary.copy(<<1>>, 11)
      assert Utils.slice_chunk(data, 0, 0, @chunk_size - 1) == data
      assert Utils.slice_chunk(data, 0, 0, @chunk_size * 3) == data
    end

    test "ranges spanning chunks" do
      data = :binary.copy(<<2>>, @chunk_size)

      assert Utils.slice_chunk(data, 1, @chunk_size - 5, @chunk_size + 4) ==
               :binary.copy(<<2>>, 5)

      assert Utils.slice_chunk(data, 1, 0, @chunk_size) == <<2>>
      assert Utils.slice_chunk(data, 2, 0, @chunk_size) == <<>>
    end

    test "short last chunk" do
      data = <<1, 2, 3>>
      assert Utils.slice_chunk(data, 3, 0, 10 * @chunk_size) == data
      assert Utils.slice_chunk(data, 3, 3 * @chunk_size + 1, 3 * @chunk_size + 1) == <<2>>
    end
  end
end
