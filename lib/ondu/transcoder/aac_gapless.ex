defmodule Ondu.Transcoder.AACGapless do
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

  @encoder_delay 1024

  @doc """
  Extracts valid sample count from a Tool.probe result.
  Accounts for encoder delay in source (AAC start_pts, etc).
  Converts sample count if source and target sample rates differ.
  """
  def source_valid_samples(probe_result, target_sample_rate) do
    stream =
      probe_result
      |> Map.get("streams", [])
      |> Enum.find(&(&1["codec_type"] == "audio"))

    tags =
      probe_result
      |> Map.get("format", %{})
      |> Map.get("tags", %{})

    with %{} <- stream,
         source_rate when is_integer(source_rate) <- to_integer(stream["sample_rate"]) do
      valid =
        case parse_itunsmpb(tags["iTunSMPB"] || tags["itunsmpb"]) do
          {:ok, smpb_valid} ->
            smpb_valid

          _ ->
            # Fallback: duration_ts - start_pts (slightly overshoots by end_padding)
            duration_ts = to_integer(stream["duration_ts"])
            start_pts = to_integer(stream["start_pts"]) || 0
            duration_ts - max(start_pts, 0)
        end

      if source_rate == target_sample_rate do
        valid
      else
        round(valid * target_sample_rate / source_rate)
      end
    else
      _ -> nil
    end
  end

  # Parses iTunSMPB tag, returns {:ok, valid_samples} or :error
  defp parse_itunsmpb(nil), do: :error

  defp parse_itunsmpb(tag_string) do
    parts = tag_string |> String.trim() |> String.split(~r/\s+/)

    if length(parts) >= 4 do
      {:ok, String.to_integer(Enum.at(parts, 3), 16)}
    else
      :error
    end
  end

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

  @doc """
  Injects an edts/elst atom into the trak to signal encoder delay to AVPlayer.
  This enables proper gapless playback on Apple platforms.
  """
  def inject_elst(file_path, source_valid_samples) when is_integer(source_valid_samples) do
    data = File.read!(file_path)

    with {moov_off, moov_size} <- find_top_atom(data, "moov"),
         moov_body <- binary_part(data, moov_off + 8, moov_size - 8),
         {trak_rel, trak_size} <- find_top_atom(moov_body, "trak"),
         trak_body <- binary_part(moov_body, trak_rel + 8, trak_size - 8) do
      # Skip if edts already exists

      with {:edts, nil} <- {:edts, find_top_atom(trak_body, "edts")},
           {:ok, movie_timescale} <- read_timescale(moov_body, "mvhd"),
           {:ok, media_timescale} <- read_media_timescale(trak_body) do
        delay = read_encoder_delay(trak_body) || @encoder_delay

        # segment_duration in movie timescale
        seg_duration = round(source_valid_samples * movie_timescale / media_timescale)

        # Build elst: version 0, 1 entry, media_rate = 1.0 (0x00010000)
        elst_body = <<0::8, 0::24, 1::32, seg_duration::32, delay::32, 1::16, 0::16>>
        elst_atom = <<byte_size(elst_body) + 8::32, "elst", elst_body::binary>>
        edts_atom = <<byte_size(elst_atom) + 8::32, "edts", elst_atom::binary>>
        edts_size = byte_size(edts_atom)

        # Insert after tkhd
        {tkhd_rel, tkhd_size} = find_top_atom(trak_body, "tkhd")
        insert_off = moov_off + 8 + trak_rel + 8 + tkhd_rel + tkhd_size

        before_b = binary_part(data, 0, insert_off)
        after_b = binary_part(data, insert_off, byte_size(data) - insert_off)
        new_data = before_b <> edts_atom <> after_b

        # Patch moov size
        <<pre_moov::binary-size(^moov_off), _::32, post_moov::binary>> = new_data
        new_data = <<pre_moov::binary, moov_size + edts_size::32, post_moov::binary>>

        # Patch trak size
        trak_abs = moov_off + 8 + trak_rel
        <<pre_trak::binary-size(^trak_abs), _::32, post_trak::binary>> = new_data
        new_data = <<pre_trak::binary, trak_size + edts_size::32, post_trak::binary>>

        File.write!(file_path, new_data)
        :ok
      else
        {:edts, _} -> :ok
        _ -> {:error, :elst_inject_failed}
      end
    else
      _ -> {:error, :elst_inject_failed}
    end
  end

  defp read_timescale(moov_body, atom_name) do
    with {rel, size} <- find_top_atom(moov_body, atom_name) do
      body = binary_part(moov_body, rel + 8, size - 8)

      case body do
        <<0::8, _::24, _create::32, _mod::32, timescale::32, _::binary>> ->
          {:ok, timescale}

        <<1::8, _::24, _create::64, _mod::64, timescale::32, _::binary>> ->
          {:ok, timescale}

        _ ->
          nil
      end
    end
  end

  defp read_media_timescale(trak_body) do
    with {mdia_rel, mdia_size} <- find_top_atom(trak_body, "mdia"),
         mdia_body <- binary_part(trak_body, mdia_rel + 8, mdia_size - 8) do
      read_timescale(mdia_body, "mdhd")
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

  defp to_integer(v) when is_integer(v), do: v
  defp to_integer(v) when is_binary(v), do: String.to_integer(v)
  defp to_integer(v) when is_float(v), do: round(v)
  defp to_integer(nil), do: nil
end
