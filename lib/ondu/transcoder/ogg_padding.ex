defmodule Ondu.Transcoder.OggPadding do
  @moduledoc """
  Pads an Ogg stream up to a promised size with empty pages, laid out so that
  the end of the file is known before the audio is.

  Readers find the duration of an Ogg file by looking for the last page near
  the end of the file, and ffmpeg (so also Chrome) gives up after about 64 KB.
  ExoPlayer reads that same end before it plays anything, and Chrome asks for
  it from a 32 KB boundary, so up to about 98 KB before the end. So the padding is
  made of pages, 27 byte headers without packets that every reader skips, and
  it is anchored at the end of the file: the pages sit on a grid counted
  back from the promised size, and the few bytes left over between the audio
  and the first page are zeros. With at least 128 KB of padding the last
  128 KB are then pages whose position, serial number, granule position and
  sequence number are all known up front, so the server can answer a request
  for the end of the file while ffmpeg is still at the beginning. The pages'
  sequence numbers are their position on the grid, which keeps them unique
  and increasing without knowing how many pages the audio takes; readers only
  care about pages that carry packets.

  The granule position they carry is the stream's final one: the pre-skip
  plus the encoded sample count, see `final_granule/3`.
  """

  import Bitwise

  @header_size 27
  # How far back from the end readers ask for the last page: ffmpeg looks
  # 64 KB back and Chrome rounds that down to a 32 KB boundary.
  @tail_bytes 131_072
  @opus_rate 48_000

  # Ogg's CRC-32: polynomial 0x04C11DB7, no reflection, zero start, no final xor.
  @table (for i <- 0..255 do
            Enum.reduce(1..8, i <<< 24, fn _, r ->
              if (r &&& 0x80000000) != 0,
                do: bxor(r <<< 1, 0x04C11DB7) &&& 0xFFFFFFFF,
                else: r <<< 1 &&& 0xFFFFFFFF
            end)
          end)
         |> List.to_tuple()

  @type info :: %{serial: non_neg_integer(), preskip: non_neg_integer(), granule: integer() | nil}

  @doc "The least padding a transcode gets, so that the last 128 KB are pages."
  @spec min_padding() :: pos_integer()
  def min_padding, do: @tail_bytes + @header_size

  @doc "How many bytes from the end can be answered before the audio exists."
  @spec tail_bytes() :: pos_integer()
  def tail_bytes, do: @tail_bytes

  @doc """
  The serial number and pre-skip of the stream, from its first page (the
  `OpusHead` page), or nil when the bytes are not the start of an Opus stream.
  """
  @spec stream_info(binary()) :: %{serial: non_neg_integer(), preskip: non_neg_integer()} | nil
  def stream_info(
        <<"OggS", 0, _flags, _granule::64, serial::little-32, _seq::32, _crc::32, segments,
          lacing::binary-size(segments), rest::binary>>
      ) do
    body_size = lacing |> :binary.bin_to_list() |> Enum.sum()

    case rest do
      <<"OpusHead", _version, _channels, preskip::little-16, _::binary>> when body_size >= 19 ->
        %{serial: serial, preskip: preskip}

      _ ->
        nil
    end
  end

  def stream_info(_bytes), do: nil

  @doc """
  The granule position the encoder will end the stream on: the pre-skip plus
  the source's sample count at Opus's 48 kHz, rounded up, which is what
  ffmpeg's resampler produces.
  """
  @spec final_granule(
          samples :: non_neg_integer(),
          rate :: pos_integer(),
          preskip :: non_neg_integer()
        ) ::
          non_neg_integer()
  def final_granule(samples, rate, preskip) do
    preskip + div(samples * @opus_rate + rate - 1, rate)
  end

  @doc """
  The padding that takes a stream of `actual` bytes to `size`: the leftover
  zeros, then pages on the grid up to the end.
  """
  @spec pad(
          actual :: non_neg_integer(),
          size :: non_neg_integer(),
          granule :: integer(),
          serial :: non_neg_integer()
        ) ::
          binary()
  def pad(actual, size, _granule, _serial) when size <= actual, do: <<>>

  def pad(actual, size, granule, serial) do
    zeros = rem(size - actual, @header_size)
    first = actual + zeros
    :binary.copy(<<0>>, zeros) <> pages(first, size, granule, serial)
  end

  @doc """
  The bytes `from` up to and including `to` of a padded stream of `size`
  bytes, for a range that lies within the pages at its end: the grid is
  anchored at `size`, so nothing about the audio is needed.
  """
  @spec tail(
          size :: non_neg_integer(),
          from :: non_neg_integer(),
          to :: non_neg_integer(),
          granule :: integer(),
          serial :: non_neg_integer()
        ) ::
          binary()
  def tail(size, from, to, granule, serial)
      when from >= size - @tail_bytes and to < size and from <= to do
    first = size - @header_size * div(size - from + @header_size - 1, @header_size)
    bytes = pages(first, size, granule, serial)
    binary_part(bytes, from - first, to - from + 1)
  end

  # Pages from `first` (on the grid) up to `size`, each numbered by its place on the grid.
  defp pages(first, size, granule, serial) do
    first
    |> Stream.iterate(&(&1 + @header_size))
    |> Stream.take_while(&(&1 < size))
    |> Enum.map_join(&page(granule, serial, div(&1, @header_size)))
  end

  @doc "Granule position, serial number and sequence number of the page that ends the tail."
  @spec last_page(binary()) :: {integer(), non_neg_integer(), non_neg_integer()} | nil
  def last_page(tail) do
    tail
    |> :binary.matches("OggS")
    |> Enum.reverse()
    |> Enum.find_value(fn {offset, _} -> page_ending_at_end(tail, offset) end)
  end

  defp page_ending_at_end(tail, offset) do
    with <<"OggS", 0, _flags, granule::little-signed-64, serial::little-32, seq::little-32,
           _crc::32, segments, lacing::binary-size(segments), rest::binary>> <-
           binary_part(tail, offset, byte_size(tail) - offset),
         true <- byte_size(rest) == lacing |> :binary.bin_to_list() |> Enum.sum() do
      {granule, serial, seq}
    else
      _ -> nil
    end
  end

  @doc false
  def page(granule, serial, seq) do
    <<head::binary-size(22), _crc::32, tail::binary>> =
      <<"OggS", 0, 0, granule::little-signed-64, serial::little-32, seq::little-32, 0::32, 0>>

    head <> <<crc(head <> <<0::32>> <> tail)::little-32>> <> tail
  end

  @doc "The Ogg page checksum, over a page with its own checksum field zeroed."
  @spec crc(binary()) :: non_neg_integer()
  def crc(data) do
    for <<byte <- data>>, reduce: 0 do
      r -> bxor(r <<< 8 &&& 0xFFFFFFFF, elem(@table, bxor(r >>> 24, byte) &&& 0xFF))
    end
  end
end
