defmodule Ondu.Transcoder.Job do
  @moduledoc false

  defstruct [:pid, :file, :preset]

  @type t :: %__MODULE__{}

  alias __MODULE__
  alias Ondu.Files.File
  alias Ondu.Storage
  alias Ondu.Tool
  alias Ondu.Transcoder.{AACGapless, Job, OggPadding, Preset, Trim, Utils}

  require Logger

  @spec start(File.t(), Preset.t()) :: t()
  def start(%File{} = file, preset) do
    parent = self()

    job = %Job{
      file: file,
      preset: preset
    }

    {:ok, pid} =
      Task.start(fn ->
        try do
          job = %{job | pid: self()}

          Logger.debug("Starting transcoding #{job.file.path} (#{job.preset.id})")
          last_chunk_index = transcode_file(job, parent)
          chunk_count = last_chunk_index + 1

          Logger.debug(
            "Finished transcoding #{job.file.path} (#{job.preset.id}, #{chunk_count} chunks)"
          )

          send(parent, {:transcoding_complete, job, chunk_count})
        rescue
          error ->
            Logger.error(
              "Failed transcoding #{job.file.path} (#{job.preset.id}): " <>
                Exception.format(:error, error, __STACKTRACE__)
            )

            send(parent, {:transcoding_failed, job})
        end
      end)

    %{job | pid: pid}
  end

  defp transcode_file(%Job{} = job, parent) do
    valid_samples = valid_samples(job.file)
    args = Preset.ffmpeg_args(job.file, job.preset, valid_samples: valid_samples)
    {:ok, port} = Tool.transcode(args)

    # ffmpeg will not create directories so we need to make sure the output
    # path exists for non streamable files.
    unless job.preset.streamable? do
      ffmpeg_output_file = Utils.tmp_file_path(job.file.id, job.preset)
      Elixir.File.mkdir_p!(Path.dirname(ffmpeg_output_file))
    end

    if job.preset.streamable? do
      read_chunks(port, job, parent)
    else
      await_transcode(port, job, parent, valid_samples)
    end
  end

  # A failed probe only means the source is transcoded whole, as it was before.
  defp valid_samples(%File{} = file) do
    case Tool.probe(Storage.get_uri(file.path)) do
      {:ok, probe} -> Trim.valid_samples(probe)
      _error -> nil
    end
  end

  # The previous chunk is kept so the padding can see the stream's last page,
  # which can be larger than what is left in the buffer at the end.
  defp read_chunks(port, job, parent, chunk_index \\ 0, buffer \\ <<>>, previous \\ <<>>) do
    chunk_size = Utils.chunk_size()
    timeout = Utils.calculate_timeout(job.file)

    receive do
      {^port, {:data, data}} ->
        new_buffer = buffer <> data

        case byte_size(new_buffer) >= chunk_size do
          true ->
            {chunk, remaining} = :erlang.split_binary(new_buffer, chunk_size)
            send(parent, {:chunk, job, chunk_index, chunk})
            read_chunks(port, job, parent, chunk_index + 1, remaining, chunk)

          false ->
            read_chunks(port, job, parent, chunk_index, new_buffer, previous)
        end

      {^port, {:exit_status, 0}} ->
        if Port.info(port), do: Port.close(port)
        buffer = pad_to_predicted_size!(job, chunk_index, buffer, previous)
        flush_chunks(parent, job, chunk_index, buffer)

      {^port, {:exit_status, status}} ->
        if Port.info(port), do: Port.close(port)
        raise "ffmpeg exited with unexpected status code (#{status})"
    after
      timeout ->
        Tool.kill(port)
        raise "ffmpeg time out"
    end
  end

  # Presets with an exact size promised that size to the clients, so the
  # output is padded up to it, see `OggPadding`. More output than promised
  # means the prediction is wrong, which cannot be served correctly.
  defp pad_to_predicted_size!(
         %Job{preset: %{exact_size?: true}} = job,
         chunk_index,
         buffer,
         previous
       ) do
    predicted = Preset.predicted_size(job.file, job.preset)
    actual = chunk_index * Utils.chunk_size() + byte_size(buffer)

    if actual > predicted do
      raise "ffmpeg output (#{actual} bytes) exceeds the predicted size (#{predicted} bytes)"
    end

    buffer <> OggPadding.pad(previous <> buffer, predicted - actual)
  end

  defp pad_to_predicted_size!(_job, _chunk_index, buffer, _previous), do: buffer

  # Sends the remaining data as chunks and returns the last chunk index.
  defp flush_chunks(_parent, _job, 0, <<>>), do: raise("ffmpeg produced no output")
  defp flush_chunks(_parent, _job, chunk_index, <<>>), do: chunk_index - 1

  defp flush_chunks(parent, job, chunk_index, data) do
    chunk_size = Utils.chunk_size()

    if byte_size(data) > chunk_size do
      {chunk, remaining} = :erlang.split_binary(data, chunk_size)
      send(parent, {:chunk, job, chunk_index, chunk})
      flush_chunks(parent, job, chunk_index + 1, remaining)
    else
      send(parent, {:chunk, job, chunk_index, data})
      chunk_index
    end
  end

  defp await_transcode(port, job, parent, valid_samples, data \\ <<>>) do
    timeout = Utils.calculate_timeout(job.file)

    receive do
      {^port, {:data, new_data}} ->
        await_transcode(port, job, parent, valid_samples, data <> new_data)

      {^port, {:exit_status, 0}} ->
        if Port.info(port), do: Port.close(port)
        consume_output_file!(job, parent, valid_samples)

      {^port, {:exit_status, status}} ->
        if Port.info(port), do: Port.close(port)
        raise "ffmpeg exited with unexpected status code (#{status})"
    after
      timeout ->
        Tool.kill(port)
        raise "ffmpeg time out"
    end
  end

  defp consume_output_file!(job, parent, valid_samples) do
    ffmpeg_output_file = Utils.tmp_file_path(job.file.id, job.preset)

    unless Elixir.File.exists?(ffmpeg_output_file) do
      raise "ffmpeg probably failed, output file not found (#{ffmpeg_output_file})"
    end

    # If needed inject the iTunSMPB tag for gapless AAC.
    maybe_make_gapless(job, valid_samples)

    # Get the File size to calculate the amount of chunks we will be streaming
    %Elixir.File.Stat{size: file_size} = Elixir.File.stat!(ffmpeg_output_file, time: :posix)
    chunk_size = Utils.chunk_size()
    chunk_count = ceil(file_size / chunk_size)

    # Now start "streaming" the output file, this will look as normal to the
    # transcoder so that should handle the persisting as well.
    Enum.each(0..(chunk_count - 1), fn chunk_index ->
      start_byte = chunk_index * chunk_size
      bytes_to_read = min(chunk_size, file_size - start_byte)

      # We are using the Storage.File driver directly because otherwise we would
      # just write the same function again. Note that using `Storage.get_bytes`
      # would use the impl (could be S3) and prefix it with the `music_path` so
      # that is why we are directly calling the implementation here.
      chunk = Storage.File.get_bytes(ffmpeg_output_file, start_byte, bytes_to_read)

      if chunk do
        send(parent, {:chunk, job, chunk_index, chunk})
      end
    end)

    # Finally we can remove the temporarily stored ffmpeg file
    Elixir.File.rm!(ffmpeg_output_file)

    # return last chunk index
    chunk_count - 1
  end

  # ffmpeg already writes the edit list and trims the last sample, which is
  # what AVPlayer needs for gapless playback. ExoPlayer reads the iTunSMPB tag
  # instead, which ffmpeg cannot write in the form it expects.
  defp maybe_make_gapless(
         %{preset: %{streamable?: false, ffmpeg_preset: :aac}} = job,
         source_valid_samples
       ) do
    ffmpeg_output_file = Utils.tmp_file_path(job.file.id, job.preset)
    sample_rate = Preset.sample_rate(job.file, job.preset)
    valid_samples = target_valid_samples(job.file, sample_rate, source_valid_samples)

    case AACGapless.inject_smpb(ffmpeg_output_file, valid_samples) do
      :ok ->
        Logger.debug("Injected iTunSMPB into the transcode of #{job.file.path}")

      error ->
        # NOTE: On failure we don't raise because the file can still be played
        # without this tag. Do log it though.
        Logger.warning(
          "Failed to inject iTunSMPB into the transcode of #{job.file.path} (#{inspect(error)})"
        )
    end
  end

  defp maybe_make_gapless(_job, _valid_samples), do: :noop

  # The valid samples at the transcode's rate: from the source's own count when
  # it has one, else from its duration (which includes any padding).
  defp target_valid_samples(
         %File{metadata: %{sample_rate: source_rate}},
         sample_rate,
         source_valid_samples
       )
       when is_integer(source_valid_samples) and is_integer(source_rate) and source_rate > 0,
       do: round(source_valid_samples * sample_rate / source_rate)

  defp target_valid_samples(%File{metadata: %{duration: duration}}, sample_rate, _samples),
    do: round(duration * sample_rate)
end
