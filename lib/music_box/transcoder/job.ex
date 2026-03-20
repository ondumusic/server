defmodule MusicBox.Transcoder.Job do
  @moduledoc false

  defstruct [:pid, :file, :preset]

  @type t :: %__MODULE__{}

  alias __MODULE__
  alias MusicBox.Files.File
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
      30_000 ->
        if Port.info(port), do: Port.close(port)
        raise "ffmpeg time out"
    end
  end

  defp await_transcode(port, job, parent, data \\ <<>>) do
    receive do
      {^port, {:data, new_data}} ->
        await_transcode(port, job, parent, data <> new_data)

      {^port, {:exit_status, 0}} ->
        if Port.info(port), do: Port.close(port)

        case persist_unstreamable(job) do
          {:ok, result} -> stream_persisted(job, parent, result)
          _ -> raise "something went wrong with persisting unstreamable transcode"
        end

      {^port, {:exit_status, status}} ->
        if Port.info(port), do: Port.close(port)
        raise "ffmpeg exited with unexpected status code (#{status})"
    after
      30_000 ->
        if Port.info(port), do: Port.close(port)
        raise "ffmpeg time out"
    end
  end

  defp persist_unstreamable(job) do
    ffmpeg_output_file = Utils.tmp_file_path(job.file.id, job.preset)

    unless Elixir.File.exists?(ffmpeg_output_file) do
      raise "ffmpeg probably failed, output file not found (#{ffmpeg_output_file})"
    end

    with false <- job.preset.streamable?,
         :aac <- job.preset.ffmpeg_preset,
         {:ok, probe_json} <- Tool.probe(job.file.path),
         valid_samples when not is_nil(valid_samples) <-
           AACGapless.source_valid_samples(probe_json, job.preset.sample_rate),
         :ok <- AACGapless.inject_smpb(ffmpeg_output_file, valid_samples),
         :ok <- AACGapless.inject_elst(ffmpeg_output_file, valid_samples) do
      Logger.debug("injected iTunSMPB into transcoded file: #{job.file.id}")
    else
      error ->
        Logger.debug(
          "failed to inject iTunSMPB into transcoded file: #{job.file.id} (#{inspect(error)})"
        )

        :noop
    end

    cache_impl().persist(job.file.id, job.preset, fn ->
      Elixir.File.stream!(ffmpeg_output_file, 4096)
    end)
    |> case do
      :ok -> Elixir.File.rm!(ffmpeg_output_file)
      {:error, :already_exists} -> Elixir.File.rm!(ffmpeg_output_file)
    end

    cache_impl().get_meta(job.file.id, job.preset)
  end

  defp stream_persisted(job, parent, result) do
    chunk_size = Utils.chunk_size()
    %{file_size: file_size, chunk_count: chunk_count} = result

    Enum.each(0..(chunk_count - 1), fn chunk_index ->
      start_byte = chunk_index * chunk_size
      bytes_to_read = min(chunk_size, file_size - start_byte)
      chunk = cache_impl().get_bytes(job.file.id, job.preset, start_byte, bytes_to_read)

      if chunk do
        send(parent, {:chunk, job, chunk_index, chunk})
      end
    end)

    # return last chunk index
    chunk_count - 1
  end

  defp cache_impl do
    Application.get_env(:music_box, MusicBox.Transcoder) |> Keyword.fetch!(:cache_impl)
  end
end
