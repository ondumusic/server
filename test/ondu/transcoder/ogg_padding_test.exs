defmodule Ondu.Transcoder.OggPaddingTest do
  use ExUnit.Case, async: true

  alias Ondu.Transcoder.OggPadding

  @fixture Path.expand("../../support/fixtures/music_files/without_tags/sample.opus", __DIR__)
  @header 27

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

  test "reads the serial and pre-skip from the first page" do
    data = File.read!(@fixture)
    assert %{serial: serial, preskip: 312} = OggPadding.stream_info(data)
    <<"OggS", 0, _flags, _granule::64, ^serial::little-32, _::binary>> = data
    assert OggPadding.stream_info(binary_part(data, 0, 30)) == nil
    assert OggPadding.stream_info("not ogg at all") == nil
  end

  test "the final granule is the pre-skip plus the resampled count, rounded up" do
    assert OggPadding.final_granule(220_500, 44_100, 312) == 240_312
    assert OggPadding.final_granule(220_501, 44_100, 312) == 240_314
    assert OggPadding.final_granule(100_003, 48_000, 312) == 100_315
    assert OggPadding.final_granule(220_501, 96_000, 312) == 110_563
  end

  test "finds the page that ends the stream" do
    data = File.read!(@fixture)
    assert {granule, serial, seq} = OggPadding.last_page(data)
    assert granule > 0 and seq > 0
    <<"OggS", 0, _flags, _granule::64, ^serial::little-32, _::binary>> = data
    assert OggPadding.last_page(:binary.part(data, 0, 10)) == nil
    assert OggPadding.last_page(data <> <<0, 0, 0>>) == nil
  end

  test "pads with zeros first and pages on a grid anchored at the end" do
    actual = 1000
    size = actual + @header * 4 + 5
    padding = OggPadding.pad(actual, size, 4321, 99)

    assert byte_size(padding) == size - actual
    <<zeros::binary-size(5), pages::binary>> = padding
    assert zeros == <<0, 0, 0, 0, 0>>

    for {page, n} <- Enum.with_index(for(<<p::binary-size(@header) <- pages>>, do: p)) do
      start = actual + 5 + n * @header

      assert <<"OggS", 0, 0, 4321::little-signed-64, 99::little-32, seq::little-32,
               crc::little-32, 0>> = page

      assert seq == div(start, @header)
      <<head::binary-size(22), _::32, tail::binary>> = page
      assert OggPadding.crc(head <> <<0::32>> <> tail) == crc
    end

    assert OggPadding.pad(size, size, 1, 1) == <<>>
    assert OggPadding.pad(size + 5, size, 1, 1) == <<>>
  end

  # What the server answers before the audio exists has to be what it writes
  # once it does, whatever size the audio turns out to have.
  test "the tail is the same bytes as the padding, for any length of audio" do
    size = 200_000

    for actual <- [size - 140_000, size - 131_100, size - 131_099 - 27 + 1, 60_000] do
      file = :binary.copy(<<7>>, actual) <> OggPadding.pad(actual, size, 555, 42)
      assert byte_size(file) == size

      for {from, to} <- [
            {size - 131_072, size - 1},
            {size - 1000, size - 1},
            {size - 131_072, size - 130_000},
            {size - 27, size - 27},
            {size - 1, size - 1}
          ] do
        assert OggPadding.tail(size, from, to, 555, 42) == binary_part(file, from, to - from + 1),
               "actual #{actual}, bytes #{from}-#{to}"
      end
    end
  end

  test "the padding is long enough for the tail to be pages" do
    assert OggPadding.min_padding() == 131_072 + 27
  end
end
