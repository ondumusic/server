defmodule MusicBox.Transcoder.Job do
  defstruct [:pid, :file, :preset]

  alias MusicBox.Transcoder.{Job, Utils}
  alias MusicBox.Files.File
  alias __MODULE__

  require Logger

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
            Logger.error("Failed transcoding file: #{job.file.id} - Error: #{error}")
            send(parent, {:transcoding_failed, job})
        end
      end)

    %{job | pid: pid}
  end

  defp ffmpeg_args(%Job{file: %File{} = file, preset: :mobile}) do
    ["-i", file.path] ++ ~w(
        -c:a libopus -b:a 128k -f webm -ar 24000
        -fflags +genpts+nobuffer -max_delay 0 -write_crc 1
        -avoid_negative_ts make_zero
        -ss 0 -t #{file.metadata.duration} -cluster_time_limit 0
        -v quiet -nostats
        pipe:1
      )
  end

  defp ffmpeg_args(%Job{file: %File{} = file, preset: _preset}) do
    ["-i", file.path] ++ ~w(
        -c:a libopus -b:a 256k -f webm -ar 48000
        -fflags +genpts+nobuffer -max_delay 0 -write_crc 1
        -avoid_negative_ts make_zero
        -ss 0 -t #{file.metadata.duration} -cluster_time_limit 0
        -v quiet -nostats
        pipe:1
      )
  end

  defp transcode_file(%Job{} = job, parent) do
    ffmpeg_bin = System.find_executable("ffmpeg")
    args = ffmpeg_args(job)

    port =
      Port.open(
        {:spawn_executable, ffmpeg_bin},
        [
          :binary,
          :stream,
          :exit_status,
          :use_stdio,
          :stderr_to_stdout,
          args: args
        ]
      )

    read_chunks(port, job, parent)
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
end
