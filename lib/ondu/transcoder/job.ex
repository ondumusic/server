defmodule Ondu.Transcoder.Job do
  @moduledoc false

  defstruct [:pid, :file, :preset]

  @type t :: %__MODULE__{}

  alias __MODULE__
  alias Ondu.Files.File
  alias Ondu.Storage
  alias Ondu.Tool
  alias Ondu.Transcoder.{Job, OggPadding, Preset, Trim, Utils}

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

    read_chunks(port, job, parent)
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
        buffer = pad_to_predicted_size(job, chunk_index, buffer, previous)
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

  # The predicted size was promised to the clients, so the output is padded
  # up to it, see `OggPadding`. More output than promised
  # means the file's stored duration is too short. The transcode is completed
  # anyway: whoever is listening right now is cut short, but once cached its
  # real size is what gets promised. Failing instead would fail every play.
  defp pad_to_predicted_size(%Job{} = job, chunk_index, buffer, previous) do
    predicted = Preset.predicted_size(job.file, job.preset)
    actual = chunk_index * Utils.chunk_size() + byte_size(buffer)

    if actual > predicted do
      Logger.warning(
        "Transcode of #{job.file.path} (#{job.preset.id}) exceeds the predicted size " <>
          "(#{actual} > #{predicted} bytes), its duration is probably wrong"
      )

      buffer
    else
      buffer <> OggPadding.pad(previous <> buffer, predicted - actual)
    end
  end

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
end
