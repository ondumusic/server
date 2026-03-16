defmodule MusicBox.Transcoder.AACGapless do
  @moduledoc """
  A module to compute and inject the iTunSMPB meta tag into AAC files.

  ## Background
  The iTunSMPB is what Apple uses for proper gapless playback support, it
  probably means "iTunes Seamless Media Playback". The problem is that our
  generated ffmpeg files don't write this into their output. This means we have
  to inject it manually after ffmpeg is completed somehow, and while there are
  some third party tool options I also wanted to avoid too many dependencies...

  So Claude (Opus 4.6) made this specific module. I only fixed compiler warnings
  """

  @doc """
  Computes iTunSMPB from the encoded output file's atoms.
  No input file needed — reads encoder delay and duration from elst/mdhd.
  """
  def compute_smpb(file_path, preset) do
    data = File.read!(file_path)

    with {moov_off, moov_size} <- find_top_atom(data, "moov"),
         moov_body = binary_part(data, moov_off + 8, moov_size - 8),
         {trak_rel, trak_size} <- find_top_atom(moov_body, "trak"),
         trak_body = binary_part(moov_body, trak_rel + 8, trak_size - 8),
         {mdia_rel, mdia_size} <- find_top_atom(trak_body, "mdia"),
         mdia_body = binary_part(trak_body, mdia_rel + 8, mdia_size - 8),
         {:ok, audio_timescale, mdhd_duration} <- parse_mdhd(mdia_body) do
      # Try to read delay from edts/elst, fall back to 1024
      {delay, original_samples} =
        with {edts_rel, edts_size} <- find_top_atom(trak_body, "edts"),
             edts_body = binary_part(trak_body, edts_rel + 8, edts_size - 8),
             {:ok, movie_timescale} <- parse_mvhd(binary_part(data, moov_off + 8, moov_size - 8)),
             {:ok, elst_duration, media_time} <- parse_elst(edts_body) do
          {media_time, round(elst_duration * audio_timescale / movie_timescale)}
        else
          _ ->
            delay = calculate_delay(preset)
            {delay, mdhd_duration - delay}
        end

      padding = mdhd_duration - delay - original_samples

      delay_hex = Integer.to_string(delay, 16) |> String.pad_leading(8, "0")
      pad_hex = Integer.to_string(max(padding, 0), 16) |> String.pad_leading(8, "0")
      samples_hex = Integer.to_string(original_samples, 16) |> String.pad_leading(16, "0")

      {:ok, "00000000 #{delay_hex} #{pad_hex} #{samples_hex}"}
    else
      _ -> {:error, :parse_failed}
    end
  end

  defp parse_mvhd(moov_body) do
    case find_top_atom(moov_body, "mvhd") do
      {off, _size} ->
        mvhd = binary_part(moov_body, off + 8, 24)

        case mvhd do
          <<0, _flags::binary-size(3), _created::32, _modified::32, timescale::32, _::binary>> ->
            {:ok, timescale}

          <<1, _flags::binary-size(3), _created::64, _modified::64, timescale::32, _::binary>> ->
            {:ok, timescale}

          _ ->
            nil
        end

      nil ->
        nil
    end
  end

  defp parse_mdhd(mdia_body) do
    case find_top_atom(mdia_body, "mdhd") do
      {off, _size} ->
        mdhd = binary_part(mdia_body, off + 8, 32)

        case mdhd do
          <<0, _flags::binary-size(3), _created::32, _modified::32, timescale::32, duration::32,
            _::binary>> ->
            {:ok, timescale, duration}

          <<1, _flags::binary-size(3), _created::64, _modified::64, timescale::32, duration::64,
            _::binary>> ->
            {:ok, timescale, duration}

          _ ->
            nil
        end

      nil ->
        nil
    end
  end

  defp parse_elst(edts_body) do
    case find_top_atom(edts_body, "elst") do
      {off, size} ->
        elst_data = binary_part(edts_body, off + 8, size - 8)

        case elst_data do
          <<0, _flags::binary-size(3), _count::32, duration::32, media_time::32-signed,
            _::binary>> ->
            {:ok, duration, max(media_time, 0)}

          <<1, _flags::binary-size(3), _count::32, duration::64, media_time::64-signed,
            _::binary>> ->
            {:ok, duration, max(media_time, 0)}

          _ ->
            nil
        end

      nil ->
        nil
    end
  end

  @doc """
  Writes iTunSMPB into existing udta/meta/ilst in the file.
  """
  def write_smpb(file_path, smpb_value) when is_binary(smpb_value) do
    data = File.read!(file_path)
    freeform = build_smpb_freeform(smpb_value)

    with {moov_off, moov_size} <- find_top_atom(data, "moov"),
         moov_body = binary_part(data, moov_off + 8, moov_size - 8),
         {udta_rel, udta_size} <- find_top_atom(moov_body, "udta"),
         udta_body = binary_part(moov_body, udta_rel + 8, udta_size - 8),
         {meta_rel, meta_size} <- find_top_atom(udta_body, "meta"),
         meta_body = binary_part(udta_body, meta_rel + 12, meta_size - 12),
         {ilst_rel, ilst_size} <- find_top_atom(meta_body, "ilst") do
      ilst_abs = moov_off + 8 + udta_rel + 8 + meta_rel + 12 + ilst_rel
      meta_abs = moov_off + 8 + udta_rel + 8 + meta_rel
      udta_abs = moov_off + 8 + udta_rel
      insert_at = ilst_abs + ilst_size
      added = byte_size(freeform)

      <<before_b::binary-size(insert_at), after_b::binary>> = data

      new_data =
        (before_b <> freeform <> after_b)
        |> update_atom_size(ilst_abs, ilst_size + added)
        |> update_atom_size(meta_abs, meta_size + added)
        |> update_atom_size(udta_abs, udta_size + added)
        |> update_atom_size(moov_off, moov_size + added)

      File.write!(file_path, new_data)
    else
      _ -> {:error, :atom_not_found}
    end
  end

  @doc """
  Computes and writes iTunSMPB in one call.
  """
  def inject_smpb(file_path, preset) do
    case compute_smpb(file_path, preset) do
      {:ok, smpb} -> write_smpb(file_path, smpb)
      error -> error
    end
  end

  defp build_smpb_freeform(value) do
    mean = atom("mean", <<0::32>> <> "com.apple.iTunes")
    name = atom("name", <<0::32>> <> "iTunSMPB")
    data = atom("data", <<0, 0, 0, 1, 0, 0, 0, 0>> <> value)
    atom("----", mean <> name <> data)
  end

  defp atom(type, payload) do
    <<byte_size(payload) + 8::32>> <> type <> payload
  end

  defp update_atom_size(data, offset, new_size) do
    <<before_b::binary-size(offset), _old::32, rest::binary>> = data
    before_b <> <<new_size::32>> <> rest
  end

  defp find_top_atom(data, target, offset \\ 0)

  defp find_top_atom(data, target, offset) when byte_size(data) >= 8 do
    <<size::32, type::binary-size(4), _::binary>> = data

    if type == target do
      {offset, size}
    else
      skip = max(size, 8)
      remaining = byte_size(data) - skip

      if remaining >= 8 do
        find_top_atom(binary_part(data, skip, remaining), target, offset + skip)
      else
        nil
      end
    end
  end

  defp find_top_atom(_, _, _), do: nil

  defp calculate_delay(preset) do
    if preset.sample_rate != 44_100 do
      raise """
      Unsupported sample rate. Your options:

      1) Change to 44100Hz
      2) Add support for other values to this module.

      The 1024 delay is hardcoded for 44100Hz which matches the standard
      ffmpeg AAC encoder delay. Other values potentially have other
      delays so this error is just to ensure you double check.
      """
    end

    1024
  end
end
