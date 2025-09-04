defmodule MusicBox.Transcoder.Job do
  defstruct [:pid, :file]

  alias MusicBox.Transcoder.{Job, Utils}
  alias MusicBox.Files.File

  require Logger

  def start(%File{} = file) do
    parent = self()

    {:ok, pid} =
      Task.start(fn ->
        try do
          Logger.info("Starting transcoding file: #{file.id}")
          last_chunk_index = transcode_file(file, parent)
          chunk_count = last_chunk_index + 1
          Logger.info("Finished transcoding file: #{file.id} (#{chunk_count} chunks)")
          send(parent, {:transcoding_complete, file, chunk_count})
        rescue
          error ->
            Logger.error("Failed transcoding file: #{file.id} - Error: #{error}")
            send(parent, {:transcoding_failed, file})
        end
      end)

    %Job{
      pid: pid,
      file: file
    }
  end

  defp ffmpeg_args(%File{path: path, metadata: %{duration: duration}}) do
    ["-i", path] ++ ~w(
        -c:a libopus -b:a 256k -f webm -ar 48000
        -fflags +genpts+nobuffer -max_delay 0 -write_crc 1
        -avoid_negative_ts make_zero
        -ss 0 -t #{duration} -cluster_time_limit 0
        -v quiet -nostats
        pipe:1
      )
  end

  defp transcode_file(%File{} = file, parent) do
    ffmpeg_bin = System.find_executable("ffmpeg")
    args = ffmpeg_args(file)

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

    read_chunks(port, file, parent)
  end

  defp read_chunks(port, file, parent, chunk_index \\ 0, buffer \\ <<>>) do
    chunk_size = Utils.chunk_size()

    receive do
      {^port, {:data, data}} ->
        new_buffer = buffer <> data

        case byte_size(new_buffer) >= chunk_size do
          true ->
            {chunk, remaining} = :erlang.split_binary(new_buffer, chunk_size)
            send(parent, {:chunk, file, chunk_index, chunk})
            read_chunks(port, file, parent, chunk_index + 1, remaining)

          false ->
            read_chunks(port, file, parent, chunk_index, new_buffer)
        end

      {^port, {:exit_status, 0}} ->
        if byte_size(buffer) > 0 do
          send(parent, {:chunk, file, chunk_index, buffer})
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
