defmodule MusicBox.FileScanner.Pipeline do
  use Broadway
  alias Broadway.Message
  alias MusicBox.FileScanner.{Analyzer, Entry, Operations, Utils}

  def start_link(opts) do
    path = Keyword.fetch!(opts, :path)

    scan_type =
      case Keyword.get(opts, :scan_type, :full) do
        :quick -> :quick
        :full -> :full
      end

    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {MusicBox.FileScanner.Producer, path},
        concurrency: 1,
        transformer: {__MODULE__, :transform, [scan_type: scan_type]}
      ],
      processors: [
        default: [concurrency: 10]
      ],
      batchers: [
        default: [concurrency: 5, batch_size: 10]
      ]
    )
  end

  @impl true
  def prepare_messages(messages, _context) do
    # If the scan type is quick we can ignore any existing files.
    found_paths =
      messages
      |> Enum.filter(&(&1.metadata.scan_type == :quick))
      |> Enum.reject(& &1.data.is_dir)
      |> Enum.map(& &1.data.path)
      |> Enum.filter(&Utils.music_file?/1)
      |> Operations.filter_existing_paths()

    messages
    |> Enum.map(fn %Message{data: %Entry{path: path}} = message ->
      if path in found_paths do
        Message.failed(message, :is_exists)
      else
        message
      end
    end)
  end

  def transform(entry, opts) do
    %Message{
      data: entry,
      metadata: %{
        scan_type: Keyword.fetch!(opts, :scan_type)
      },
      acknowledger: {__MODULE__, :default, :ack_data}
    }
  end

  def ack(:default, successful, failed) do
    successful
    |> Enum.map(& &1.data)
    |> Operations.batch_insert()

    # Send directory entries back to a random producer to walk them and find
    # even more files and/or directories.
    failed
    |> Enum.filter(&(&1.status == {:failed, :is_directory}))
    |> Enum.map(& &1.data)
    |> Operations.walk_entries(__MODULE__)
  end

  @impl true

  def handle_message(_processor, %Message{data: %Entry{is_dir: true}} = message, _context),
    do: Message.failed(message, :is_directory)

  def handle_message(_processor, %Message{status: :ok} = message, _context) do
    if Utils.music_file?(message.data.path) do
      Message.update_data(message, &Analyzer.analyze/1)
    else
      Message.failed(message, :is_unknown)
    end
  end

  def handle_message(_processor, message, _context),
    do: message

  @impl true
  def handle_batch(:default, messages, _batch_info, _context),
    do: messages
end
