defmodule MusicBox.Transcoder.Job do
  @moduledoc false

  defstruct [:pid, :file, :preset]

  @type t :: %__MODULE__{}

  alias __MODULE__
  alias MusicBox.Files.File
  alias MusicBox.Storage
  alias MusicBox.Tool
  alias MusicBox.Transcoder.{AACGapless, Job, Preset, Utils}

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

          Logger.debug("Starting transcoding file: #{job.file.id}")
          last_chunk_index = transcode_file(job, parent)
          chunk_count = last_chunk_index + 1
          Logger.debug("Finished transcoding file: #{job.file.id} (#{chunk_count} chunks)")
          send(parent, {:transcoding_complete, job, chunk_count})
        rescue
          error ->
            Logger.error(
              "Failed transcoding file: #{job.file.id} - Error: #{Exception.message(error)}"
            )

            Logger.error(Exception.format_stacktrace())

            send(parent, {:transcoding_failed, job})
        end
      end)

    %{job | pid: pid}
  end

  defp transcode_file(%Job{} = job, parent) do
    args = Preset.ffmpeg_args(job.file, job.preset)
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
      await_transcode(port, job, parent)
    end
  end

  defp read_chunks(port, job, parent, chunk_index \\ 0, buffer \\ <<>>) do
    chunk_size = Utils.chunk_size()
    timeout = Utils.calculate_timeout(job.file)

    receive do
      {^port, {:data, data}} ->
        new_buffer = buffer <> data

        case byte_size(new_buffer) >= chunk_size do
          true ->
            {chunk, remaining} = :erlang.split_binary(new_buffer, chunk_size)
            send(parent, {:chunk, job, chunk_index, chunk})
            read_chunks(port, job, parent, chunk_index + 1, remaining)

          false ->
            read_chunks(port, job, parent, chunk_index, new_buffer)
        end

      {^port, {:exit_status, 0}} ->
        if byte_size(buffer) > 0 do
          send(parent, {:chunk, job, chunk_index, buffer})
        end

        if Port.info(port), do: Port.close(port)
        chunk_index

      {^port, {:exit_status, status}} ->
        if Port.info(port), do: Port.close(port)
        raise "ffmpeg exited with unexpected status code (#{status})"
    after
      timeout ->
        if Port.info(port), do: Port.close(port)
        raise "ffmpeg time out"
    end
  end

  defp await_transcode(port, job, parent, data \\ <<>>) do
    timeout = Utils.calculate_timeout(job.file)

    receive do
      {^port, {:data, new_data}} ->
        await_transcode(port, job, parent, data <> new_data)

      {^port, {:exit_status, 0}} ->
        if Port.info(port), do: Port.close(port)
        consume_output_file!(job, parent)

      {^port, {:exit_status, status}} ->
        if Port.info(port), do: Port.close(port)
        raise "ffmpeg exited with unexpected status code (#{status})"
    after
      timeout ->
        if Port.info(port), do: Port.close(port)
        raise "ffmpeg time out"
    end
  end

  defp consume_output_file!(job, parent) do
    ffmpeg_output_file = Utils.tmp_file_path(job.file.id, job.preset)

    unless Elixir.File.exists?(ffmpeg_output_file) do
      raise "ffmpeg probably failed, output file not found (#{ffmpeg_output_file})"
    end

    # If needed inject the iTunSMPB tag for gapless AAC.
    maybe_make_gapless(job)

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

  defp maybe_make_gapless(%{preset: %{streamable?: false, ffmpeg_preset: :aac}} = job) do
    ffmpeg_output_file = Utils.tmp_file_path(job.file.id, job.preset)
    sample_rate = Preset.sample_rate(job.file, job.preset)

    with {:ok, probe_json} <- Tool.probe(Storage.get_uri(job.file.path)),
         valid_samples when not is_nil(valid_samples) <-
           AACGapless.source_valid_samples(probe_json, sample_rate),
         :ok <- AACGapless.inject_smpb(ffmpeg_output_file, valid_samples),
         :ok <- AACGapless.inject_elst(ffmpeg_output_file, valid_samples) do
      Logger.debug("injected iTunSMPB into transcoded file: #{job.file.id}")
    else
      error ->
        # NOTE: On failure we don't raise because the file can still be played
        # without this tag. Do log it though.
        Logger.warning(
          "failed to inject iTunSMPB into transcoded file: #{job.file.id} (#{inspect(error)})"
        )

        :noop
    end
  end

  defp maybe_make_gapless(_job), do: :noop
end
