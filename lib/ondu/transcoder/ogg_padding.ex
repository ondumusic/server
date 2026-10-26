defmodule Ondu.Transcoder.OggPadding do
  @moduledoc """
  Pads an Ogg stream up to a promised size with empty pages.

  Readers find the duration of an Ogg file by looking for the last page near
  the end of the file, and ffmpeg (so also Chrome) gives up after about 64 KB.
  Zeros past that point would hide the last page, so the padding is made of
  pages instead: 27 byte headers without packets that carry the last page's
  granule position and continue its sequence, which every reader skips and
  which keep the stream's end where it is. The last few bytes under one header
  are zeros.
  """

  import Bitwise

  @header_size 27

  # Ogg's CRC-32: polynomial 0x04C11DB7, no reflection, zero start, no final xor.
  @table (for i <- 0..255 do
            Enum.reduce(1..8, i <<< 24, fn _, r ->
              if (r &&& 0x80000000) != 0,
                do: bxor(r <<< 1, 0x04C11DB7) &&& 0xFFFFFFFF,
                else: r <<< 1 &&& 0xFFFFFFFF
            end)
          end)
         |> List.to_tuple()

  @doc """
  Padding of `size` bytes for the stream whose end is in `tail`. The tail has
  to contain the stream's last page, whole. Zeros when it does not.
  """
  @spec pad(tail :: binary(), size :: non_neg_integer()) :: binary()
  def pad(_tail, size) when size <= 0, do: <<>>

  def pad(tail, size) do
    case last_page(tail) do
      {granule, serial, seq} ->
        pages = div(size, @header_size)

        Enum.map_join(1..pages//1, &empty_page(granule, serial, seq + &1)) <>
          :binary.copy(<<0>>, size - pages * @header_size)

      nil ->
        :binary.copy(<<0>>, size)
    end
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
  def empty_page(granule, serial, seq) do
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
