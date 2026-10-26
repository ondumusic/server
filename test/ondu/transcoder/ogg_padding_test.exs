defmodule Ondu.Transcoder.OggPaddingTest do
  use ExUnit.Case, async: true

  alias Ondu.Transcoder.OggPadding

  @fixture Path.expand("../../support/fixtures/music_files/without_tags/sample.opus", __DIR__)

  test "the checksum matches what the encoder wrote" do
    data = File.read!(@fixture)
    {offset, _} = :binary.matches(data, "OggS") |> Enum.at(1)
    <<page::binary-size(27), _::binary>> = binary_part(data, offset, byte_size(data) - offset)
    <<head::binary-size(22), written::little-32, segments, _::binary>> = page
    lacing = binary_part(data, offset + 27, segments)
    body_size = lacing |> :binary.bin_to_list() |> Enum.sum()
    page = binary_part(data, offset, 27 + segments + body_size)
    <<_::binary-size(22), _crc::32, rest::binary>> = page

    assert OggPadding.crc(head <> <<0::32>> <> rest) == written
  end

  test "finds the page that ends the stream" do
    data = File.read!(@fixture)
    assert {granule, serial, seq} = OggPadding.last_page(data)
    assert granule > 0 and seq > 0
    # the file's serial, from its first page
    <<"OggS", 0, _flags, _granule::64, ^serial::little-32, _::binary>> = data
    assert OggPadding.last_page(:binary.part(data, 0, 10)) == nil
    assert OggPadding.last_page(data <> <<0, 0, 0>>) == nil
  end

  test "pads with empty pages continuing the stream, and zeros for the rest" do
    data = File.read!(@fixture)
    {granule, serial, seq} = OggPadding.last_page(data)
    padding = OggPadding.pad(data, 100)

    assert byte_size(padding) == 100

    <<first::binary-size(27), second::binary-size(27), third::binary-size(27), rest::binary>> =
      padding

    assert rest == <<0::size(19 * 8)>>

    for {page, n} <- Enum.with_index([first, second, third], 1) do
      assert <<"OggS", 0, 0, ^granule::little-signed-64, ^serial::little-32, page_seq::little-32,
               crc::little-32, 0>> = page

      assert page_seq == seq + n
      <<head::binary-size(22), _::32, tail::binary>> = page
      assert OggPadding.crc(head <> <<0::32>> <> tail) == crc
    end

    # readers see the same end: ffmpeg reports the same duration, and no error
    assert OggPadding.last_page(data <> OggPadding.pad(data, 27 * 3)) ==
             {granule, serial, seq + 3}
  end

  test "zeros when there is no page to continue" do
    assert OggPadding.pad(<<1, 2, 3>>, 30) == <<0::size(30 * 8)>>
    assert OggPadding.pad(<<>>, 0) == <<>>
  end
end
