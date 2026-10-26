defmodule Ondu.Transcoder.AACGapless do
  @moduledoc """
  Computes and injects the iTunSMPB tag into AAC (M4A) files.

  ## Background
  iTunSMPB ("iTunes Seamless Media Playback") describes the encoder delay,
  end padding and valid sample count of an AAC stream. ffmpeg already writes
  an edit list (`elst`) and trims the last sample, which is what AVPlayer uses
  for gapless playback, but ExoPlayer reads this tag from the `udta` atom
  instead and ffmpeg cannot write it in that form (its `use_metadata_tags`
  flag writes `mdta` keys, which ExoPlayer ignores for gapless).
  """

  @encoder_delay 1024

  @doc """
  Computes iTunSMPB from the encoded output file and the source valid sample count.
  """
  def compute_smpb(file_path, source_valid_samples) do
    data = File.read!(file_path)

    with {moov_off, moov_size} <- find_top_atom(data, "moov"),
         moov_body = binary_part(data, moov_off + 8, moov_size - 8),
         {trak_rel, trak_size} <- find_top_atom(moov_body, "trak"),
         trak_body = binary_part(moov_body, trak_rel + 8, trak_size - 8),
         {mdia_rel, mdia_size} <- find_top_atom(trak_body, "mdia"),
         mdia_body = binary_part(trak_body, mdia_rel + 8, mdia_size - 8),
         {:ok, total_encoded} <- parse_stts(mdia_body) do
      delay = read_encoder_delay(trak_body) || @encoder_delay
      padding = total_encoded - delay - source_valid_samples

      delay_hex = Integer.to_string(delay, 16) |> String.pad_leading(8, "0")
      pad_hex = Integer.to_string(max(padding, 0), 16) |> String.pad_leading(8, "0")
      samples_hex = Integer.to_string(source_valid_samples, 16) |> String.pad_leading(16, "0")

      {:ok, "00000000 #{delay_hex} #{pad_hex} #{samples_hex}"}
    else
      _ -> {:error, :parse_failed}
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

      <<before_b::binary-size(^insert_at), after_b::binary>> = data

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
  def inject_smpb(file_path, source_valid_samples) do
    case compute_smpb(file_path, source_valid_samples) do
      {:ok, smpb} -> write_smpb(file_path, smpb)
      error -> error
    end
  end

  # MARK: - Atom parsers

  defp read_encoder_delay(trak_body) do
    with {edts_rel, edts_size} <- find_top_atom(trak_body, "edts"),
         edts_body <- binary_part(trak_body, edts_rel + 8, edts_size - 8),
         {:ok, _duration, media_time} <- parse_elst(edts_body),
         true <- media_time > 0 do
      media_time
    else
      _ -> nil
    end
  end

  defp parse_stts(mdia_body) do
    with {minf_rel, minf_size} <- find_top_atom(mdia_body, "minf"),
         minf_body = binary_part(mdia_body, minf_rel + 8, minf_size - 8),
         {stbl_rel, stbl_size} <- find_top_atom(minf_body, "stbl"),
         stbl_body = binary_part(minf_body, stbl_rel + 8, stbl_size - 8),
         {stts_rel, stts_size} <- find_top_atom(stbl_body, "stts") do
      stts_data = binary_part(stbl_body, stts_rel + 8, stts_size - 8)
      <<_version, _flags::binary-size(3), entry_count::32, entries::binary>> = stts_data
      {:ok, sum_stts_entries(entries, entry_count, 0)}
    else
      _ -> nil
    end
  end

  defp sum_stts_entries(_data, 0, acc), do: acc

  defp sum_stts_entries(<<count::32, delta::32, rest::binary>>, remaining, acc) do
    sum_stts_entries(rest, remaining - 1, acc + count * delta)
  end

  defp sum_stts_entries(_, _, acc), do: acc

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

  # MARK: - Atom writing helpers

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
    <<before_b::binary-size(^offset), _old::32, rest::binary>> = data
    before_b <> <<new_size::32>> <> rest
  end

  # MARK: - Atom search

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
end
