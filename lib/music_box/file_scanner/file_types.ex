defmodule MusicBox.FileScanner.FileTypes do
  @m4a_signature <<0x66::size(8), 0x74::size(8), 0x79::size(8), 0x70::size(8), 0x4D::size(8),
                   0x34::size(8),
                   0x41::size(8)>> ||
                   <<0x4D::size(8), 0x34::size(8), 0x41::size(8), 0x20::size(8)>>
  def detect(<<_, _, _, _, @m4a_signature, _rest::binary>>), do: {:ok, :m4a}

  @mp3_signature <<0x49::size(8), 0x44::size(8), 0x33::size(8)>> ||
                   <<0xFF::size(8), 0xFB::size(8)>>
  def detect(<<@mp3_signature, _rest::binary>>), do: {:ok, :mp3}

  @opus_signature <<0x4F::size(8), 0x70::size(8), 0x75::size(8), 0x73::size(8), 0x48::size(8),
                    0x65::size(8), 0x61::size(8), 0x64::size(8)>>
  def detect(
        <<_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _,
          @opus_signature, _rest::binary>>
      ),
      do: {:ok, :opus}

  @ogg_signature <<0x4F::size(8), 0x67::size(8), 0x67::size(8), 0x53::size(8)>>
  def detect(<<@ogg_signature, _rest::binary>>), do: {:ok, :ogg}

  @flac_signature <<0x66::size(8), 0x4C::size(8), 0x61::size(8), 0x43::size(8)>>
  def detect(<<@flac_signature, _rest::binary>>), do: {:ok, :flac}

  @wav_signature <<0x52::size(8), 0x49::size(8), 0x46::size(8), 0x46::size(8)>>
  @wav_signature_alt <<0x57::size(8), 0x41::size(8), 0x56::size(8), 0x45::size(8)>>
  def detect(<<@wav_signature, _, _, _, _, @wav_signature_alt, _rest::binary>>), do: {:ok, :wav}

  def detect(_), do: {:error, :unknown_type}
end
