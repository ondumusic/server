defmodule Ondu.FileScanner.FileTypes do
  @moduledoc false

  @type t :: :aac | :aiff | :m4a | :mp3 | :opus | :ogg | :flac | :wav

  @spec detect(binary()) :: {:ok, t()} | {:error, :unknown_type}

  # --- M4A ---
  # Must come before AAC/MP3 since it's detected by "ftyp" at offset 4.
  # The ftyp box can contain various brands (M4A, mp42, isom, etc.)
  # so we just check for "ftyp" rather than a specific brand.
  @ftyp <<0x66, 0x74, 0x79, 0x70>>
  def detect(<<_size::binary-size(4), @ftyp, _rest::binary>>), do: {:ok, :m4a}

  # --- MP3 (ID3v2 tag) ---
  # Must come before AAC since both use 0xFF sync bytes.
  # ID3 is unambiguous so check it first.
  @id3_signature <<0x49, 0x44, 0x33>>
  def detect(<<@id3_signature, _rest::binary>>), do: {:ok, :mp3}

  # --- MP3 (raw MPEG frame sync) ---
  # 0xFF 0xFB/0xFA = MPEG1 Layer 3, 0xFF 0xF3/0xF2 = MPEG2 Layer 3
  def detect(<<0xFF, sync, _rest::binary>>) when sync in [0xFB, 0xFA, 0xF3, 0xF2],
    do: {:ok, :mp3}

  # --- AAC (ADTS frame sync) ---
  # 0xFF 0xF1 = MPEG-4 AAC, 0xFF 0xF9 = MPEG-2 AAC
  def detect(<<0xFF, sync, _rest::binary>>) when sync in [0xF1, 0xF9],
    do: {:ok, :aac}

  # --- AIFF / AIFF-C ---
  @form_signature <<0x46, 0x4F, 0x52, 0x4D>>
  @aiff_type <<0x41, 0x49, 0x46, 0x46>>
  @aifc_type <<0x41, 0x49, 0x46, 0x43>>
  def detect(<<@form_signature, _::binary-size(4), @aiff_type, _rest::binary>>), do: {:ok, :aiff}
  def detect(<<@form_signature, _::binary-size(4), @aifc_type, _rest::binary>>), do: {:ok, :aiff}

  # --- Opus ---
  # OGG container with "OpusHead" at offset 28. Must come before generic OGG.
  @ogg_signature <<0x4F, 0x67, 0x67, 0x53>>
  @opus_head <<0x4F, 0x70, 0x75, 0x73, 0x48, 0x65, 0x61, 0x64>>
  def detect(<<@ogg_signature, _::binary-size(24), @opus_head, _rest::binary>>), do: {:ok, :opus}

  # --- OGG Vorbis (generic) ---
  def detect(<<@ogg_signature, _rest::binary>>), do: {:ok, :ogg}

  # --- FLAC ---
  @flac_signature <<0x66, 0x4C, 0x61, 0x43>>
  def detect(<<@flac_signature, _rest::binary>>), do: {:ok, :flac}

  # --- WAV ---
  @riff_signature <<0x52, 0x49, 0x46, 0x46>>
  @wave_format <<0x57, 0x41, 0x56, 0x45>>
  def detect(<<@riff_signature, _::binary-size(4), @wave_format, _rest::binary>>), do: {:ok, :wav}

  def detect(_), do: {:error, :unknown_type}
end
