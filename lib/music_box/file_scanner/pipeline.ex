defmodule MusicBox.FileScanner.Pipeline do
  use Broadway
  alias Broadway.Message
  alias MusicBox.FileScanner.{Analyzer, Entry, Utils}

  def start_link(opts) do
    path = Keyword.fetch!(opts, :path)

    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {MusicBox.FileScanner.Producer, path},
        concurrency: 1,
        transformer: {__MODULE__, :transform, []}
      ],
      processors: [
        default: [concurrency: 10]
      ],
      batchers: [
        directories: [concurrency: 5, batch_size: 10],
        unknowns: [concurrency: 2, batch_size: 10],
        files: [concurrency: 2, batch_size: 10]
      ]
    )
  end

  def transform(entry, _opts) do
    %Message{
      data: entry,
      batcher: get_batcher(entry),
      acknowledger: {__MODULE__, get_acknowledger(entry), :ack_data}
    }
  end

  def ack(:file, successful, _failed) do
    IO.inspect(successful)

    :noop
  end

  def ack(:directory, [] = _successful, [] = _failed),
    do: :noop

  def ack(:directory, successful, [] = _failed) do
    entries = Enum.map(successful, & &1.data)

    # Send directory entries back to a random producer to walk them and find
    # even more files and/or directories.
    Broadway.producer_names(__MODULE__)
    |> Enum.random()
    |> case do
      nil -> :noop
      producer -> GenStage.call(producer, {:walk, entries})
    end
  end

  @impl true
  def handle_message(_processor, %Message{batcher: :files} = message, _context) do
    message
    |> Message.update_data(&Analyzer.analyze/1)
  end

  def handle_message(_processor, message, _context),
    do: message

  @impl true
  def handle_batch(:unknowns, messages, _batch_info, _context),
    do: Enum.map(messages, &Message.failed(&1, :is_unknown))

  def handle_batch(_batch_group, messages, _batch_info, _context),
    do: messages

  defp get_acknowledger(%Entry{is_dir: true}), do: :directory
  defp get_acknowledger(%Entry{is_dir: false}), do: :file

  defp get_batcher(%Entry{is_dir: true}), do: :directories

  defp get_batcher(%Entry{path: path}) do
    if Utils.music_file?(path) do
      :files
    else
      :unknowns
    end
  end
end
